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
    ROOT_UID=0              # Only users with $UID 0 have root privileges
    DWNLD_DIR="/tmp"        # Reliable location to place artifacts

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
