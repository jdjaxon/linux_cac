#!/usr/bin/env bash

# cac_setup.sh
# Author: Jeremy Jackson
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

    # Prevent cackey from upgrading
    # If cackey upgrades from 7.5 to 7.10, it moves libcackey.so to a different location,
    # breaking Firefox.
    if apt-mark hold cackey
    then
        echo -e "${INFO_COLOR}[INFO] Hold placed on cackey package${NO_COLOR}"
    else
        echo -e "${ERR_COLOR}[ERROR] Failed to place hold on cackey package${NO_COLOR}"
    fi

    # Unzip cert bundle
    mkdir -p "$DWNLD_DIR/$CERT_FILENAME"
    unzip "$DWNLD_DIR/$BUNDLE_FILENAME" -d "$DWNLD_DIR/$CERT_FILENAME"