check_for_chrome()
{
    # Check to see if Chrome exists
    if command -v google-chrome-stable >/dev/null
    then
        chrome_exists=true
        print_info "Found Google Chrome."
    else
        print_info "Chrome not found."
    fi
}


setup()
{
    # Find all Firefox databases
    mapfile -t databases < <(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox\|pki" | grep -v "Trash")
    # Check if databases were found properly
    if [ "${#databases[@]}" -eq 0 ]
    then
        # Database was not found
        print_err "No valid databases located. Try running, then closing Firefox, then start this script again."
        echo -e "\tExiting..."

        exit "$E_DATABASE"
    fi

    # Install middleware and necessary utilities
    print_info "Installing middleware..."
    pacman -Sy --noconfirm # Update package list
    pacman -S --noconfirm ccid opensc pcsc-tools nss unzip wget
    print_info "Done"

    # Pull all necessary files
    print_info "Downloading DoD certificates and Cackey package..."
    wget -qP "$DWNLD_DIR" "$CERT_URL"
    wget -qP "$DWNLD_DIR" "$CACKEY_URL"
    print_info "Done."


    # Install libcackey.
    if command -v yay >/dev/null 2>&1; then
        print_info "Installing libcackey using yay..."
        sudo -u "$SUDO_USER" yay -S --noconfirm cackey
    elif command -v paru >/dev/null 2>&1; then
        print_info "Installing libcackey using paru..."
        sudo -u "$SUDO_USER" paru -S --noconfirm cackey
    else
        print_err "Neither yay nor paru is available. Please install one of them and try again."
        exit 1
    fi

    # Check if libcackey.so is installed
    libcackey_path=$(find /usr -name "libcackey.so" | head -n 1)
    if [ -z "$libcackey_path" ]; then
        print_err "libcackey.so not found after installation. Please check the installation manually."
        exit 1
    else
        print_info "libcackey.so found at $libcackey_path"
    fi
}
