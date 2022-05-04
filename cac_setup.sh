#!/usr/bin/env bash

# cac_setup.sh
# Description: Setup a Linux environment for Common Access Card use.

main ()
{
    # For colorization
    ERR_COLOR='\033[0;31m'  # Red for error messages
    INFO_COLOR='\033[0;33m' # Yellow for notes
    NO_COLOR='\033[0m'      # Revert terminal back to no color

    EXIT_SUCCESS=0          # Success exit code
    E_INSTALL=85            # Installation failed
    E_NOTROOT=86            # Non-root exit error
    E_BROWSER=87            # Compatible browser not found
    ROOT_UID=0              # Only users with $UID 0 have root privileges
    DWNLD_DIR="/tmp"        # Reliable location to place artifacts
    CHROME_EXISTS=0         # Google Chrome is installed
    ff_exists=0             # Firefox is installed
    snap_ff=0               # Flag to prompt for how to handle snap Firefox

    ORIG_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    CERT_EXTENSION="cer"
    PKCS_FILENAME="pkcs11.txt"
    DB_FILENAME="cert9.db"
    CERT_FILENAME="AllCerts"
    BUNDLE_FILENAME="AllCerts.zip"
    CERT_URL="http://militarycac.com/maccerts/$BUNDLE_FILENAME"
    PKG_FILENAME="cackey_0.7.5-1_amd64.deb"
    CACKEY_URL="http://cackey.rkeene.org/download/0.7.5/$PKG_FILENAME"

    # Ensure the script is ran as root
    if [ "${EUID:-$(id -u)}" -ne "$ROOT_UID" ]
    then
        echo -e "${ERR_COLOR}[ERROR] Please run this script as root.${NO_COLOR}"
        exit "$E_NOTROOT"
    fi

    # Check to see if firefox exists
    echo -e "${INFO_COLOR}[INFO] Checking for Firefox and Chrome...${NO_COLOR}"
    if which firefox >/dev/null
    then
        ff_exists=1
        echo -e "${INFO_COLOR}[INFO] Found Firefox.${NO_COLOR}"
        echo -e "${INFO_COLOR}[INFO] Installation method:${NO_COLOR}"
        if which firefox | grep snap >/dev/null
        then
            snap_ff=1
            echo -e "${ERR_COLOR}\t(oh) SNAP!${NO_COLOR}"
        else

        echo -e "${INFO_COLOR}\tapt (or just not snap):${NO_COLOR}"
        fi
    fi

    # Check to see if Chrome exists
    if which google-chrome
    then
        CHROME_EXISTS=1
        echo -e "${INFO_COLOR}[INFO] Found Google Chrome.${NO_COLOR}"
    fi

    # Browser check results
    if [ "$ff_exists" -eq 0 ] && [ "$CHROME_EXISTS" -eq 0 ]
    then
        echo -e "${ERR_COLOR}No version of Mozilla Firefox OR Google Chrome have \
        been detected.\nPlease install either or both to proceed.${NO_COLOR}"

        exit "$E_BROWSER"

    elif [ "$ff_exists" -eq 1 ]
    then
        echo "DEBUG: CHECKING FOR SNAP"
        if [ "$snap_ff" -eq 1 ]
        then

        echo "DEBUG: SNAP WAS FOUND"
            echo -e "${INFO_COLOR}\
            ********************[IMPORTANT]********************\n
            * The version of Firefox you have installed       *\n
            * currently was installed via snap.               *\n
            * This version of Firefox is not currently        *\n
            * compatible with the method used to enable CAC   *\n
            * support in browsers.                            *\n
            *                                                 *\n
            * As a work-around, this script can automatically *\n
            * remove the snap version and reinstall via apt.  *\n
            *                                                 *\n
            * If you are not signed in to Firefox, you will   *\n
            * likely lose bookmarks or other personalizations *\n
            * set in the current variant of Firefox.          *\n
            ********************[IMPORTANT]********************\n
            ${NO_COLOR}"

            choice=''

            while [ "$choice" != "y" ] && [ "$choice" != "n" ]
            do
                echo -e "${ERR_COLOR}\nWould you like to proceed with the switch to \
                the apt version? (\"y/n\")${NO_COLOR}"

                read -rp '> ' choice
            done

            if [ "$choice" == "y" ]
            then
                snap remove firefox

                add-apt-repository -y ppa:mozillateam/ppa

                echo '
                Package: *
                Pin: release o=LP-PPA-mozillateam
                Pin-Priority: 1001
                ' | tee /etc/apt/preferences.d/mozilla-firefox

                echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

                apt install firefox
            else
                if [ $CHROME_EXISTS -eq 0 ]
                then
                    echo -e "${ERR_COLOR}You have elected to keep the snap \
                    version of Firefox. You also do not currently have \
                    Google Chrome installed. Therefore, you have no compatible \
                    browsers. \n\n Exiting!\n${NO_COLOR}"

                    exit $E_BROWSER
                fi
            fi
        fi

    fi



    # Install middleware and necessary utilities
    echo -e "${INFO_COLOR}[INFO] Installing middleware...${NO_COLOR}"
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools libnss3-tools unzip wget
    echo "Done"

    # Pull all necessary files
    echo -e "${INFO_COLOR}[INFO] Downloading DoD certificates and Cackey package...${NO_COLOR}"
    wget -qP "$DWNLD_DIR" "$CERT_URL"
    wget -qP "$DWNLD_DIR" "$CACKEY_URL"
    echo "Done."

    # Install libcackey.
    echo -e "${INFO_COLOR}[INFO] Installing libcackey...${NO_COLOR}"
    if dpkg -i "$DWNLD_DIR/$PKG_FILENAME"
    then
        echo "Done."
    else
        echo -e "${ERR_COLOR}[ERROR] Installation failed. Exiting...${NO_COLOR}"
        exit "$E_INSTALL"
    fi

    # Prevent cackey from upgrading.
    # If cackey upgrades beyond 7.5, it moves libcackey.so to a different location,
    # breaking Firefox. Returning libcackey.so to the original location does not
    # seem to fix this issue.
    if apt-mark hold cackey
    then
        echo -e "${INFO_COLOR}[INFO] Hold placed on cackey package${NO_COLOR}"
    else
        echo -e "${ERR_COLOR}[ERROR] Failed to place hold on cackey package${NO_COLOR}"
    fi

    # Unzip cert bundle
    mkdir -p "$DWNLD_DIR/$CERT_FILENAME"
    unzip "$DWNLD_DIR/$BUNDLE_FILENAME" -d "$DWNLD_DIR/$CERT_FILENAME"

    # From testing on Ubuntu 22.04, this process doesn't seem to work well with applications
    # installed via snap, so the script will ignore databases within snap.
    mapfile -t databases < <(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox\|pki" | grep -v "snap")
    for db in "${databases[@]}"
    do
        if [ -n "$db" ]
        then
            db_root="$(dirname "$db")"
            if [ -n "$db_root" ]
            then
                case "$db_root" in
                    *"pki"*)
                        echo -e "${INFO_COLOR}Importing certificates for Chrome...${NO_COLOR}"
                        echo
                        ;;
                    *"firefox"*)
                        echo -e "${INFO_COLOR}Importing certificates for Firefox...${NO_COLOR}"
                        echo
                        ;;
                esac

                echo -e "${INFO_COLOR}[INFO] Loading certificates into $db_root ${NO_COLOR}"
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
        else
            echo -e "${INFO_COLOR}[INFO] No databases found.${NO_COLOR}"
        fi
    done

    # Remove artifacts
    echo -e "${INFO_COLOR}[INFO] Removing artifacts...${NO_COLOR}"
    rm -rf "${DWNLD_DIR:?}"/{"$BUNDLE_FILENAME","$CERT_FILENAME","$PKG_FILENAME"}
    if [ "$?" -ne "$EXIT_SUCCESS" ]
    then
        echo -e "${ERR_COLOR}[ERROR] Failed to remove artifacts${NO_COLOR}"
    else
        echo "Done."
    fi

    exit "$EXIT_SUCCESS"
}

main
