#!/usr/bin/env bash

# cac_setup_fedora.sh
# Description: Setup a Fedora Linux environment for Common Access Card use.

main ()
{
    EXIT_SUCCESS=0                      # Success exit code
    E_NOTROOT=86                        # Non-root exit error
    E_BROWSER=87                        # Compatible browser not found
    E_DATABASE=88                       # No database located
    DWNLD_DIR="/tmp"                    # Location to place artifacts

    chrome_exists=false                 # Google Chrome is installed
    ff_exists=false                     # Firefox is installed

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
        print_err "No valid databases located. Try running, then closing Firefox/Chrome, then start this script again."
        echo -e "\tExiting..."
        exit "$E_DATABASE"
    fi

    # Install middleware and necessary utilities
    print_info "Installing middleware and essential utilities..."
    dnf install -y pcsc-lite pcsc-lite-ccid opensc nss-tools unzip wget pcsc-tools
    print_info "Done"

    # Pull all necessary files
    print_info "Downloading DoD certificates..."
    wget -qP "$DWNLD_DIR" "$CERT_URL"
    print_info "Done."

    # Unzip cert bundle
    if [ -e "$DWNLD_DIR/$BUNDLE_FILENAME" ]
    then
        mkdir -p "$DWNLD_DIR/$CERT_FILENAME"
        unzip -q "$DWNLD_DIR/$BUNDLE_FILENAME" -d "$DWNLD_DIR/$CERT_FILENAME"
    fi

    # Import certificates into cert9.db databases for browsers
    for db in "${databases[@]}"
    do
        if [ -n "$db" ]
        then
            import_certs "$db"
        fi
    done

    print_info "Verifying PKCS11 module registration..."
    # On Fedora, OpenSC module is automatically registered via p11-kit
    if p11-kit list-modules | grep -q opensc; then
        print_info "OpenSC PKCS11 module is properly registered"
    else
        print_err "OpenSC PKCS11 module not found. You may need to reinstall opensc package."
    fi
    print_info "Done"

    print_info "Enabling pcscd service to start on boot..."
    systemctl enable pcscd.socket
    systemctl start pcscd.socket
    print_info "Done"

    # Remove artifacts
    print_info "Removing artifacts..."
    rm -rf "${DWNLD_DIR:?}"/{,"$BUNDLE_FILENAME","$CERT_FILENAME"} 2>/dev/null
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
    print_info "Running Chrome to ensure it has completed post-install actions..."
    sudo -H -u "$SUDO_USER" google-chrome --headless --disable-gpu >/dev/null 2>&1 &
    sleep 3
    pkill -9 google-chrome
    sleep 1
    print_info "Done."
} # run_chrome


# Discovery of browsers installed on the user's system
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
check_for_firefox ()
{
    if command -v firefox >/dev/null
    then
        ff_exists=true
        print_info "Found Firefox."
        # Run Firefox to ensure .mozilla directory has been created
        print_info "Running Firefox to generate profile directory..."
        run_firefox
        print_info "Done."
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


main
