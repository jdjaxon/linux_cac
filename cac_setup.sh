#!/usr/bin/env bash

# cac_setup.sh
# Description: Setup a Linux environment for Common Access Card use.

main ()
{
    EXIT_SUCCESS=0                      # Success exit code
    E_NOTROOT=86                        # Non-root exit error
    E_BROWSER=87                        # Browser-related error (e.g. no browser installed)
    E_DATABASE=88                       # No database located
    DWNLD_DIR="/tmp"                    # Location to place artifacts

    chrome_exists=false                 # Google Chrome is installed
    ff_exists=false                     # Firefox is installed
    snap_ff=false                       # Snapped Firefox
    ff_profile_dir=""                   # Firefox profile directory

    ORIG_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    CERT_EXTENSION="cer"
    DB_FILENAME="cert9.db"
    CERT_FILENAME="AllCerts"
    BUNDLE_FILENAME="AllCerts.zip"
    CERT_URL="https://militarycac.com/maccerts/$BUNDLE_FILENAME"

    root_check
    browser_check
    mapfile -t databases < <(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox\|pki" | grep -v "Trash")
    # Check if databases were found properly
    if [ "${#databases[@]}" -eq 0 ]
    then
        print_err "No valid databases located. Try running, then closing Firefox, then start this script again."
        echo -e "\tExiting..."

        exit "$E_DATABASE"
    fi

    # Install middleware and necessary utilities
    print_info "Installing middleware and essential utilities..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools libnss3-tools unzip wget opensc
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

    print_info "Enabling pcscd service to start on boot..."
    systemctl enable pcscd.socket
    print_info "Done"

    # Connect snapped Firefox to the pcscd socket
    if [ "$snap_ff" == true ]
    then
        print_info "Connecting snapped Firefox to the pcscd socket..."
        if ! snap connect firefox:pcscd
        then
            print_err "Failed to connect. Try upgrading with 'apt upgrade' and 'snap refresh' first."
            exit "$E_BROWSER"
        fi
    fi

    # Register the PKCS11 module in every detected NSS database (Firefox + Chrome)
    opensc_lib=$(find_opensc_pkcs11)
    if [ -z "$opensc_lib" ]
    then
        print_err "Could not locate opensc-pkcs11.so; skipping PKCS11 module registration."
    else
        for db in "${databases[@]}"
        do
            if [ -n "$db" ]
            then
                register_pkcs11_module "$(dirname "$db")" "$opensc_lib"
            fi
        done
    fi


    # Remove artifacts
    print_info "Removing artifacts..."
    rm -rf "${DWNLD_DIR:?}"/{"$BUNDLE_FILENAME","$CERT_FILENAME"} 2>/dev/null
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
    fi
} # browser_check


# Attempt to find an installed version of Firefox on the user's system
# Determines whether the version is installed via snap or apt
check_for_firefox ()
{
    if command -v firefox >/dev/null
        then
            # Run Firefox to ensure .mozilla directory has been created
            print_info "Running Firefox to generate profile directory..."
            run_firefox
            print_info "Done."

            ff_exists=true
            db_location="$(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox" | grep -v "Trash")"
            ff_profile_dir="$(dirname "$db_location")"
            print_info "Found Firefox with profile in ${ff_profile_dir}"

            if command -v firefox | grep snap >/dev/null
            then
                snap_ff=true
                print_info "This version of Firefox was installed as a snap package"
            elif command -v firefox | xargs grep -Fq "exec /snap/bin/firefox"
            then
                snap_ff=true
                print_info "This version of Firefox was installed as a snap package with a launch script"
            else
                print_info "This is not a snap-installed version of Firefox."
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


# Locate opensc-pkcs11.so on the system
find_opensc_pkcs11 ()
{
    local lib_path
    lib_path=$(dpkg -L opensc 2>/dev/null | grep 'opensc-pkcs11\.so$' | head -1)
    if [ -z "$lib_path" ]
    then
        # potential for non-debian-based systems
        lib_path=$(find /usr/lib /usr/local/lib -name 'opensc-pkcs11.so' 2>/dev/null | head -1)
    fi
    echo "$lib_path"
} # find_opensc_pkcs11


# Register opensc-pkcs11.so as a PKCS11 module in a single NSS database dir.
register_pkcs11_module ()
{
    local db_dir="$1"
    local lib_path="$2"
    print_info "Registering PKCS11 module in ${db_dir}..."
    sudo -H -u "$SUDO_USER" modutil -dbdir "sql:${db_dir}" \
        -add "CAC Module" -libfile "$lib_path" -force
} # register_pkcs11_module


main
