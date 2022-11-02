#!/usr/bin/env bash

# cac_setup.sh
# Description: Setup a Linux environment for Common Access Card use.

main ()
{
    EXIT_SUCCESS=0                      # Success exit code
    E_INSTALL=85                        # Installation failed
    E_NOTROOT=86                        # Non-root exit error
    E_BROWSER=87                        # Compatible browser not found
    E_DATABASE=88                       # No database located
    DWNLD_DIR="/tmp"                    # Reliable location to place artifacts
    FF_PROFILE_NAME="old_ff_profile"    # Reliable location to place artifacts

    chrome_exists=false                 # Google Chrome is installed
    ff_exists=false                     # Firefox is installed
    snap_ff=false                       # Flag to prompt for how to handle snap Firefox

    ORIG_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    CERT_EXTENSION="cer"
    PKCS_FILENAME="pkcs11.txt"
    DB_FILENAME="cert9.db"
    CERT_FILENAME="AllCerts"
    BUNDLE_FILENAME="AllCerts.zip"
    CERT_URL="http://militarycac.com/maccerts/$BUNDLE_FILENAME"
    PKG_FILENAME="cackey_0.7.5-1_amd64.deb"
    CACKEY_URL="http://cackey.rkeene.org/download/0.7.5/$PKG_FILENAME"

    root_check
    browser_check

    mapfile -t databases < <(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox\|pki" | grep -v "Trash\|snap")
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
    print_info "Installing middleware..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools libnss3-tools unzip wget
    print_info "Done"

    # Pull all necessary files
    print_info "Downloading DoD certificates and Cackey package..."
    wget -qP "$DWNLD_DIR" "$CERT_URL"
    wget -qP "$DWNLD_DIR" "$CACKEY_URL"
    print_info "Done."

    # Install libcackey.
    if [ -e "$DWNLD_DIR/$PKG_FILENAME" ]
    then
        print_info "Installing libcackey..."
        if dpkg -i "$DWNLD_DIR/$PKG_FILENAME"
        then
            print_info "Done."
        else
            print_err "Installation failed. Exiting..."

            exit "$E_INSTALL"
        fi
    fi

    # Prevent cackey from upgrading.
    # If cackey upgrades beyond 7.5, it moves libcackey.so to a different location,
    # breaking Firefox. Returning libcackey.so to the original location does not
    # seem to fix this issue.
    if apt-mark hold cackey
    then
        print_info "Hold placed on cackey package"
    else
        print_err "Failed to place hold on cackey package"
    fi

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

    print_info "Enabling pcscd service to start on boot..."
    systemctl enable pcscd.socket

    # Remove artifacts
    print_info "Removing artifacts..."
    rm -rf "${DWNLD_DIR:?}"/{"$BUNDLE_FILENAME","$CERT_FILENAME","$PKG_FILENAME","$FF_PROFILE_NAME"} 2>/dev/null
    if [ "$?" -ne "$EXIT_SUCCESS" ]
    then
        print_err "Failed to remove artifacts"
    else
        print_info "Done."
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
    local ROOT_UID=0              # Only users with $UID 0 have root privileges

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
    apt install firefox -y
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

run_firefox ()
{
    print_info "Starting Firefox silently to complete post-install actions..."
        sudo -H -u "$SUDO_USER" firefox --headless --first-startup >/dev/null 2>&1 &
        sleep 3
        pkill -9 firefox
        sleep 1
}

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
}

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
# TODO: original location in the event of a failed install
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

}

# Attempt to find an installed version of Firefox on the user's system
# Determines whether the version is installed via snap or apt
check_for_firefox ()
{
    if command -v firefox >/dev/null
        then
            ff_exists=true
            print_info "Found Firefox."
            if command -v firefox | grep snap >/dev/null
            then
                snap_ff=true
                print_err "This version of Firefox was installed as a snap package"
            else
                # Run Firefox to ensure .mozilla directory has been created
                echo -e "Running Firefox to generate profile directory..."
                sudo -H -u "$SUDO_USER" bash -c 'firefox --headless --first-startup >/dev/null 2>&1 &'
                sleep 3
                pkill -9 firefox
                sleep 1
                echo -e "\tDone."
            fi
        else
            print_info "Firefox not found."
        fi
}
# Attempt to find a version of Google Chrome installed on the user's system
check_for_chrome ()
{
    # Check to see if Chrome exists
    if command -v google-chrome >/dev/null
    then
        chrome_exists=true
        print_info "Found Google Chrome."
        # Run Chrome to ensure .pki directory has been created
#        echo -e "\tRunning Chrome to ensure it has completed post-install actions..."
#        # TODO: finish troubleshooting this
#        sudo -H -u "$SUDO_USER" bash -c 'google-chrome --headless --disable-gpu >/dev/null 2>&1 &'
#        sleep 3
#        pkill -9 google-chrome
#        sleep 1
#        echo -e "\tDone."
    else
        print_info "Chrome not found."
    fi
}

# Re-install the user's previous version of Firefox if the snap version was
# removed in the process of this script.
revert_firefox ()
{
    # Firefox was replaced, lets put it back where it was.
    print_err "No valid databases located. Reinstalling previous version of Firefox..."
    apt purge firefox -y
    snap install firefox

    run_firefox

    print_info "Completed. Exiting..."

    # "Restore" old profile back to the snap version of Firefox
    migrate_ff_profile "restore"

    exit "$E_DATABASE"
}

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

        if ! grep -Pzo 'library=/usr/lib64/libcackey.so\nname=CAC Module\n' "$db_root/$PKCS_FILENAME" >/dev/null
        then
            printf "library=/usr/lib64/libcackey.so\nname=CAC Module\n" >> "$db_root/$PKCS_FILENAME"
        fi
    fi

    echo "Done."
    echo
} # import_certs

# Check to see if the user has Firefox pinned to their favorites bar in GNOME
check_for_ff_pin ()
{
    # firefox is a favorite and if gnome is the desktop environment.

    if sudo -u "$SUDO_USER" bash -c "$(echo "$XDG_CURRENT_DESKTOP" | grep "GNOME" >/dev/null 2>&1)"
    then
        print_info "Detected Gnome desktop environment"
        if  echo "$curr_favorites" | grep "firefox.desktop" >/dev/null 2>&1
        then
            ff_was_pinned=true
        else
            print_info "Firefox not pinned to favorites"
        fi
    else
        print_err "Desktop environment not yet supported."
        print_err "Unable to repin Firefox to favorites bar"
        print_info "Firefox can still be repinned manually"
    fi
} # check_for_ff_pin

repin_firefox ()
{
    print_info "Attempting to repin Firefox to favorites bar..."
    if [ $ff_was_pinned == true ]
    then

        # TODO: finish this

        curr_favorites=$(gsettings get org.gnome.shell favorite-apps)
        print_info "Repinning Firefox to favorites bar"

        gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'firefox.desktop']"

        print_info "Done."

    fi

} # repin_firefox

main
