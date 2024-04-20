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

# Attempt to find a version of Google Chrome installed on the user's system
check_for_chrome()
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


setup()
{
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
}
