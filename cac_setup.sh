#!/usr/bin/env bash

# cac_setup.sh
# Description: Setup a Linux environment for Common Access Card use.

main ()
{
    EXIT_SUCCESS=0                      # Success exit code
    E_NOTROOT=86                        # Non-root exit error
    E_BROWSER=87                        # Compatible browser not found
    E_DATABASE=88                       # No database located
    E_DISTRO=89                         # Unsupported Linux distribution
    DWNLD_DIR="/tmp"                    # Location to place artifacts
    FF_PROFILE_NAME="old_ff_profile"    # Location to save old Firefox profile

    chrome_exists=false                 # Google Chrome is installed
    ff_exists=false                     # Firefox is installed
    snap_ff=false                       # Flag to prompt for how to handle snap Firefox
    OS_FAMILY=""                        # Detected OS family (debian/fedora/arch)

    ORIG_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    CERT_EXTENSION="cer"
    # PKCS_FILENAME="pkcs11.txt"
    DB_FILENAME="cert9.db"
    CERT_FILENAME="AllCerts"
    BUNDLE_FILENAME="AllCerts.zip"
    CERT_URL="https://militarycac.com/maccerts/$BUNDLE_FILENAME"

    detect_os
    root_check
    browser_check

    # Exclude snap paths only on Debian-family systems
    if [ "$OS_FAMILY" == "debian" ]
    then
        mapfile -t databases < <(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox\|pki" | grep -v "Trash\|snap")
    else
        mapfile -t databases < <(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox\|pki" | grep -v "Trash")
    fi

    # Check if databases were found properly
    if [ "${#databases[@]}" -eq 0 ]
    then
        # Database was not found
        if [ "$snap_ff" == true ]
        then
            revert_firefox
        else
            # Firefox was not replaced, exit with E_DATABASE error
            print_err "No valid databases located. Try running, then closing Firefox, then start this script again."
            echo -e "\tExiting..."

            exit "$E_DATABASE"
        fi
    else
        # Database was found. (Good)
        if [ "$snap_ff" == true ]
        then
            # Database was found, meaning snap firefox was replaced with apt version
            # This conditional branch may not be needed at all... Note: Remove if not needed
            snap_ff=false
        fi
    fi

    # Install middleware and necessary utilities
    print_info "Installing middleware and essential utilities..."
    install_packages
    print_info "Done"

    # Pull all necessary files
    print_info "Downloading DoD certificates..."
    wget -qP "$DWNLD_DIR" "$CERT_URL"
    print_info "Done."

    # Unzip cert bundle
    if [ -e "$DWNLD_DIR/$BUNDLE_FILENAME" ]
    then
        mkdir -p "$DWNLD_DIR/$CERT_FILENAME"
        unzip "$DWNLD_DIR/$BUNDLE_FILENAME" -d "$DWNLD_DIR/$CERT_FILENAME"
    fi

    # Import certificates into cert9.db databases for browsers
    for db in "${databases[@]}"
    do
        if [ -n "$db" ]
        then
            import_certs "$db"
        fi
    done

    register_pkcs11

    # NOTE: Keeping this temporarily to test `pkcs11-register`.
    # if ! grep -Pzo 'library=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so\nname=CAC Module\n' "$db_root/$PKCS_FILENAME" >/dev/null
    # then
    #     printf "library=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so\nname=CAC Module\n" >> "$db_root/$PKCS_FILENAME"
    # fi

    print_info "Enabling pcscd service to start on boot..."
    systemctl enable pcscd.socket
    if [ "$OS_FAMILY" != "debian" ]
    then
        systemctl start pcscd.socket
    fi
    print_info "Done"

    # Remove artifacts
    print_info "Removing artifacts..."
    rm -rf "${DWNLD_DIR:?}"/{"$BUNDLE_FILENAME","$CERT_FILENAME","$FF_PROFILE_NAME"} 2>/dev/null
    if [ "$?" -ne "$EXIT_SUCCESS" ]
    then
        print_err "Failed to remove artifacts. Artifacts were stored in ${DWNLD_DIR}."
    else
        print_info "Done. A reboot may be required."
    fi

    exit "$EXIT_SUCCESS"
} # main


# Prints message with red [ERROR] tag before the message
print_err ()
{
    ERR_COLOR='\033[0;31m'  # Red for error messages
    NO_COLOR='\033[0m'      # Revert terminal back to no color
    echo -e "${ERR_COLOR}[ERROR]${NO_COLOR} $1"
} # print_err


# Prints message with yellow [INFO] tag before the message
print_info ()
{
    INFO_COLOR='\033[0;33m' # Yellow for notes
    NO_COLOR='\033[0m'      # Revert terminal back to no color
    echo -e "${INFO_COLOR}[INFO]${NO_COLOR} $1"
} # print_info


# Check to ensure the script is executed as root
root_check ()
{
    # Only users with $UID 0 have root privileges
    local ROOT_UID=0

    # Ensure the script is ran as root
    if [ "${EUID:-$(id -u)}" -ne "$ROOT_UID" ]
    then
        print_err "Please run this script as root."
        exit "$E_NOTROOT"
    fi
} # root_check


# Replace the current snap version of Firefox with the compatible apt version of Firefox
reconfigure_firefox ()
{
    # Replace snap Firefox with version from PPA maintained via Mozilla
    check_for_ff_pin
    #Profile migration
    backup_ff_profile
    print_info "Removing Snap version of Firefox"
    snap remove --purge firefox
    print_info "Adding PPA for Mozilla maintained Firefox"
    add-apt-repository -y ppa:mozillateam/ppa
    print_info "Setting priority to prefer Mozilla PPA over snap package"
    echo -e "Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001" > /etc/apt/preferences.d/mozilla-firefox
    print_info "Enabling updates for future Firefox releases"
    # shellcheck disable=SC2016
    echo -e 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' > /etc/apt/apt.conf.d/51unattended-upgrades-firefox
    print_info "Installing Firefox via apt"
    DEBIAN_FRONTEND=noninteractive apt install -y --allow-downgrades firefox
    print_info "Completed re-installation of Firefox"

    # Forget the previous location of firefox executable
    if hash firefox
    then
        hash -d firefox
    fi

    run_firefox
    print_info "Finished, closing Firefox."

    if [ "$backup_exists" == true ]
    then
        print_info "Migrating user profile into newly installed Firefox"
        migrate_ff_profile "migrate"
    fi

    repin_firefox
} # reconfigure_firefox


# Run Firefox to ensure the profile directory has been created
run_firefox ()
{
    print_info "Starting Firefox silently to complete post-install actions..."
    sudo -H -u "$SUDO_USER" firefox --headless --first-startup >/dev/null 2>&1 &
    sleep 3
    pkill -9 firefox
    sleep 1
} # run_firefox


# Run Chrome to ensure .pki directory has been created
run_chrome ()
{
    # NOTE: this is the original
    # sudo -H -u "$SUDO_USER" bash -c 'google-chrome --headless --disable-gpu >/dev/null 2>&1 &'

    # TODO: finish troubleshooting this
    print_info "Running Chrome to ensure it has completed post-install actions..."
    sudo -H -u "$SUDO_USER" google-chrome --headless --disable-gpu >/dev/null 2>&1 &
    sleep 3
    pkill -9 google-chrome
    sleep 1
    print_info "Done."
} # run_chrome


# Discovery of browsers installed on the user's system
# Sets appropriate flags to control the flow of the installation, depending on
# what is needed for the individual user
browser_check ()
{
    print_info "Checking for Firefox and Chrome..."
    check_for_firefox
    check_for_chrome

    # Browser check results
    if [ "$ff_exists" == false ] && [ "$chrome_exists" == false ]
    then
        print_err "No version of Mozilla Firefox OR Google Chrome has been detected."
        print_info "Please install either or both to proceed."
        exit "$E_BROWSER"
    elif [ "$ff_exists" == true ] # Firefox was found
    then
        if [ "$snap_ff" == true ] # Snap version of Firefox
        then
            echo -e "
            ********************${ERR_COLOR}[ WARNING ]${NO_COLOR}********************
            * The version of Firefox you have installed       *
            * currently was installed via snap.               *
            * This version of Firefox is not currently        *
            * compatible with the method used to enable CAC   *
            * support in browsers.                            *
            *                                                 *
            * As a work-around, this script can automatically *
            * remove the snap version and reinstall via apt.  *
            *                                                 *
            * The option to attempt to migrate all of your    *
            * personalizations will be given if you choose to *
            * replace Firefox via this script. Your Firefox   *
            * profile will be saved to a temp location, then  *
            * will overwrite the default profile once the apt *
            * version of Firefox has been installed.          *
            *                                                 *
            ********************${ERR_COLOR}[ WARNING ]${NO_COLOR}********************\n"

            # Prompt user to elect to replace snap firefox with apt firefox
            choice=''
            while [ "$choice" != "y" ] && [ "$choice" != "n" ]
            do
                echo -e "\nWould you like to switch to the apt version of Firefox? ${INFO_COLOR}(y/n)${NO_COLOR}"
                read -rp '> ' choice
            done

            if [ "$choice" == "y" ]
            then
                reconfigure_firefox
            else
                if [ $chrome_exists == false ]
                then
                    print_info "You have elected to keep the snap version of Firefox.\n"
                    print_err "You have no compatible browsers. Exiting..."
                    exit $E_BROWSER
                fi
            fi
        fi
    fi
} # browser_check


# Locate and backup the profile for the user's snap version of Firefox
# Backup is placed in /tmp/ff_old_profile/ and can be restored after the
# apt version of Firefox has been installed
backup_ff_profile ()
{
    location="$(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox" | grep -v "Trash" | grep snap)"
    if [ -z "$location" ]
    then
        print_info "No user profile was found in snap-installed version of Firefox."
    else
        # A user profile exists in the snap version of FF
        choice=''
        while [ "$choice" != "y" ] && [ "$choice" != "n" ]
        do
            echo -e "\nWould you like to transfer your bookmarks and personalizations to the new version of Firefox? ${INFO_COLOR}(y/n)${NO_COLOR}"
            read -rp '> ' choice
        done

        if [ "$choice" == "y" ]
        then
            print_info "Backing up Firefox profile"
            ff_profile="$(dirname "$location")"
            sudo -H -u "$SUDO_USER" cp -rf "$ff_profile" "$DWNLD_DIR/$FF_PROFILE_NAME"
            backup_exists=1
        fi

    fi
} # backup_ff_profile


# Moves the user's backed up Firefox profile from the temp location to the newly
# installed apt version of Firefox in the ~/.mozilla directory
# TODO: Take arguments for source and destination so profile can be restored to
#       original location in the event of a failed install
migrate_ff_profile ()
{
    direction=$1

    if [ "$direction" == "migrate" ]
    then
        apt_ff_profile="$(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox" | grep -v "Trash" | grep -v snap)"
        if [ -z "$apt_ff_profile" ]
        then
            print_err "Something went wrong while trying to find apt Firefox's user profile directory."
            exit "$E_DATABASE"
        else
            ff_profile_dir="$(dirname "$apt_ff_profile")"
            if sudo -H -u "$SUDO_USER" cp -rf "$DWNLD_DIR/$FF_PROFILE_NAME"/* "$ff_profile_dir"
            then
                print_info "Successfully migrated user profile for Firefox versions"
            else
                print_err "Unable to migrate Firefox profile"
            fi
        fi
    elif [ "$direction" == "restore" ]
    then
        location="$(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox" | grep -v "Trash" | grep snap)"
        if [ -z "$location" ]
        then
            print_info "No user profile was found in snap-installed version of Firefox."
        else
            ff_profile_dir="$(dirname "$apt_ff_profile")"
            if sudo -H -u "$SUDO_USER" cp -rf "$DWNLD_DIR/$FF_PROFILE_NAME"/* "$ff_profile_dir"
            then
                print_info "Successfully restored user profile for Firefox"
            else
                print_err "Unable to migrate Firefox profile"
            fi
        fi
    fi

} # migrate_ff_profile


# Attempt to find an installed version of Firefox on the user's system
# Determines whether the version is installed via snap or apt (Debian family only)
check_for_firefox ()
{
    local ff_path
    ff_path="$(command -v firefox)"
    if [ -n "$ff_path" ]
    then
        ff_exists=true
        print_info "Found Firefox."
        if [ "$OS_FAMILY" == "debian" ]
        then
            if echo "$ff_path" | grep snap >/dev/null
            then
                snap_ff=true
                print_err "This version of Firefox was installed as a snap package"
            elif grep -Fq "exec /snap/bin/firefox" "$ff_path"
            then
                snap_ff=true
                print_err "This version of Firefox was installed as a snap package with a launch script"
            else
                # Run Firefox to ensure .mozilla directory has been created
                print_info "Running Firefox to generate profile directory..."
                run_firefox
                print_info "Done."
            fi
        else
            # Run Firefox to ensure .mozilla directory has been created
            print_info "Running Firefox to generate profile directory..."
            run_firefox
            print_info "Done."
        fi
    else
        print_info "Firefox not found."
    fi
} # check_for_firefox


# Attempt to find a version of Google Chrome installed on the user's system
check_for_chrome ()
{
    # Check to see if Chrome exists
    if command -v google-chrome >/dev/null
    then
        chrome_exists=true
        print_info "Found Google Chrome."
        # Run Chrome to ensure .pki directory has been created
        run_chrome
    else
        print_info "Chrome not found."
    fi
} # check_for_chrome


# Reinstall the user's previous version of Firefox if the snap version was
# removed in the process of this script.
revert_firefox ()
{
    # Firefox was replaced, let's put it back where it was.
    print_err "No valid databases located. Reinstalling previous version of Firefox..."
    DEBIAN_FRONTEND=noninteractive apt purge firefox -y
    snap install firefox
    run_firefox
    print_info "Completed. Exiting..."
    # "Restore" the old profile back to the snap version of Firefox
    migrate_ff_profile "restore"

    exit "$E_DATABASE"
} # revert_firefox


# Integrate all certificates into the databases for existing browsers
import_certs ()
{
    db=$1
    db_root="$(dirname "$db")"
    if [ -n "$db_root" ]
    then
        case "$db_root" in
            *"pki"*)
                print_info "Importing certificates for Chrome..."
                echo
                ;;
            *"firefox"*)
                print_info "Importing certificates for Firefox..."
                echo
                ;;
        esac

        print_info "Loading certificates into $db_root "
        echo

        for cert in "$DWNLD_DIR/$CERT_FILENAME/"*."$CERT_EXTENSION"
        do
            echo "Importing $cert"
            certutil -d sql:"$db_root" -A -t TC -n "$cert" -i "$cert"
        done
    fi

    print_info "Done."
    echo
} # import_certs


# Check to see if the user has Firefox pinned to their favorites bar in GNOME
check_for_ff_pin ()
{
    if [ -z "$XDG_CURRENT_DESKTOP" ]; then
        print_info "Desktop environment information not available."
        return
    fi

    if echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"
    then
        print_info "Detected GNOME-based desktop environment"
        if echo "$curr_favorites" | grep -q "firefox.desktop"
        then
            ff_was_pinned=true
        fi
    else
        print_err "Unsupported desktop environment."
        print_err "Unable to repin Firefox to favorites bar"
        print_info "Firefox can still be pinned manually"
    fi
} # check_for_ff_pin


repin_firefox ()
{
    print_info "Attempting to repin Firefox to favorites bar..."
    if [ "$ff_was_pinned" == true ]
    then
        curr_favorites=$(gsettings get org.gnome.shell favorite-apps)
        print_info "Pinning Firefox to favorites bar"
        gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'firefox.desktop']"
        print_info "Done."
    fi
} # repin_firefox


# Detect the Linux distribution family and set OS_FAMILY accordingly
detect_os ()
{
    if [ ! -f /etc/os-release ]
    then
        print_err "Cannot detect Linux distribution. /etc/os-release not found."
        exit "$E_DISTRO"
    fi

    # shellcheck source=/dev/null
    . /etc/os-release

    local distro_id="${ID:-}"
    local distro_like="${ID_LIKE:-}"
    local distro_info="$distro_id $distro_like"

    if echo "$distro_info" | grep -qi "debian\|ubuntu"
    then
        OS_FAMILY="debian"
    elif echo "$distro_info" | grep -qi "fedora\|rhel\|centos"
    then
        OS_FAMILY="fedora"
    elif echo "$distro_info" | grep -qi "arch"
    then
        OS_FAMILY="arch"
    else
        print_err "Unsupported Linux distribution: ${PRETTY_NAME:-$distro_id}"
        print_info "Supported distributions: Debian/Ubuntu, Fedora, Arch Linux"
        exit "$E_DISTRO"
    fi

    print_info "Detected OS: ${PRETTY_NAME:-$distro_id} (family: $OS_FAMILY)"
} # detect_os


# Install middleware packages using the appropriate package manager
install_packages ()
{
    case "$OS_FAMILY" in
        debian)
            apt update
            DEBIAN_FRONTEND=noninteractive apt install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools libnss3-tools unzip wget opensc
            ;;
        fedora)
            dnf install -y pcsc-lite pcsc-lite-ccid opensc nss-tools unzip wget pcsc-tools
            ;;
        arch)
            pacman -Sy --noconfirm pcsclite ccid opensc nss unzip wget pcsc-tools
            ;;
    esac
} # install_packages


# Register the CAC PKCS11 module using the appropriate method for the OS family
register_pkcs11 ()
{
    case "$OS_FAMILY" in
        debian)
            print_info "Registering CAC module with PKCS11..."
            pkcs11-register
            print_info "Done"
            ;;
        fedora|arch)
            print_info "Verifying PKCS11 module registration..."
            # OpenSC module is automatically registered via p11-kit on Fedora and Arch
            if p11-kit list-modules | grep -q opensc
            then
                print_info "OpenSC PKCS11 module is properly registered"
            else
                print_err "OpenSC PKCS11 module not found. You may need to reinstall opensc package."
            fi
            print_info "Done"
            ;;
    esac
} # register_pkcs11


main
