#!/usr/bin/env bash

# cac_setup.sh
# Author: Jeremy Jackson
# Date: 24 Feb 2022
# Description: Setup a Linux environment for Common Access Card use.

main ()
{
    # For colorization
    ERR_COLOR='\033[0;31m' # Red for error messages
    NO_COLOR='\033[0m'     # Revert terminal back to no color

    EXIT_SUCCESS=0         # Success exit code
    E_INSTALL=85           # Installation failed
    E_NOTROOT=86           # Non-root exit error
    ROOT_UID=0             # Only users with $UID 0 have root privileges
    DWNLD_DIR="/tmp"       # Reliable location to place artifacts

    ORIG_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    CERT_EXTENSION="cer"
    PKCS_FILENAME="pkcs11.txt"
    NSSDB_FILENAME="cert9.db"
    CERT_FILENAME="AllCerts"
    BUNDLE_FILENAME="AllCerts.zip"
    CERT_URL="http://militarycac.com/maccerts/$BUNDLE_FILENAME"
    PKG_FILENAME="cackey_0.7.5-1_amd64.deb"
    CACKEY_URL="http://cackey.rkeene.org/download/0.7.5/$PKG_FILENAME"

    # Ensure the script is ran as root
    if [ "${EUID:-$(id -u)}" -ne "$ROOT_UID" ]
    then
        echo "Please run this script as root."
        exit "$E_NOTROOT"
    fi

    # Install middleware and necessary utilities
    echo "Installing middleware..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools libnss3-tools unzip wget
    echo "Done"

    # Pull all necessary files
    echo "Downloading DoD certificates and Cackey package..."
    wget -qP "$DWNLD_DIR" "$CERT_URL"
    wget -qP "$DWNLD_DIR" "$CACKEY_URL"
    echo "Done."

    # Install libcackey.
    echo "Installing libcackey..."
    if dpkg -i "$DWNLD_DIR/$PKG_FILENAME"
    then
        echo "Done."
    else
        echo "${ERR_COLOR}error:${NO_COLOR} installation failed. Exitting..."
        exit "$E_INSTALL"
    fi

    # Prevent cackey from upgrading
    # If cackey upgrades from 7.5 to 7.10, it moves libcackey.so to a different location,
    # breaking Firefox.
    if apt-mark hold cackey
    then
        echo "Hold placed on cackey package."
    else
        echo "${ERR_COLOR}error:${NO_COLOR} failed to place hold on cackey package."
    fi

    # Unzip cert bundle
    mkdir -p "$DWNLD_DIR/$CERT_FILENAME"
    unzip "$DWNLD_DIR/$BUNDLE_FILENAME" -d "$DWNLD_DIR/$CERT_FILENAME"

    # Check for Chrome
    if sudo -u $SUDO_USER google-chrome --version
    then
        # Locate Firefox's database directory in the user's profile
        if chrome_cert_DB="$(dirname "$(find "$ORIG_HOME/.pki" -name "$NSSDB_FILENAME")")"
        then
            # Import DoD certificates
            echo "Importing DoD certificates for Chrome..."
            for cert in "$DWNLD_DIR/$CERT_FILENAME/"*."$CERT_EXTENSION"
            do
                echo "Importing $cert"
                certutil -d sql:"$chrome_cert_DB" -A -t TC -n "$cert" -i "$cert"
            done

            # Point DB security module to libcackey.so with the PKCS file, if it exists.
            if [ -f "$chrome_cert_DB/$PKCS_FILENAME" ]
            then
                printf "library=/usr/lib64/libcackey.so\nname=CAC Module\n" >> "$chrome_cert_DB/$PKCS_FILENAME"
            fi

            echo "Done."
        else
            echo "${ERR_COLOR}error:${NO_COLOR} unable to find Chromes's certificate database"
        fi
    fi

    # Check for Firefox
    if sudo -u $SUDO_USER firefox --version
    then
        # Locate Firefox's database directory in the user's profile
        if firefox_cert_DB="$(dirname "$(find "$ORIG_HOME/.mozilla/" -name "$NSSDB_FILENAME")")"
        then
            # Import DoD certificates
            echo "Importing DoD certificates for Firefox..."
            for cert in "$DWNLD_DIR/$CERT_FILENAME/"*."$CERT_EXTENSION"
            do
                echo "Importing $cert"
                certutil -d sql:"$firefox_cert_DB" -A -t TC -n "$cert" -i "$cert"
            done

            # Point DB security module to libcackey.so with the PKCS file, if it exists.
            if [ -f "$firefox_cert_DB/$PKCS_FILENAME" ]
            then
                printf "library=/usr/lib64/libcackey.so\nname=CAC Module\n" >> "$firefox_cert_DB/$PKCS_FILENAME"
            fi

            echo "Done."
        else
            echo "${ERR_COLOR}error:${NO_COLOR} unable to find Firefox's certificate database"
        fi
    fi

    # Remove artifacts
    echo "Removing artifacts..."
    rm -rf "${DWNLD_DIR:?}"/{"$BUNDLE_FILENAME","$CERT_FILENAME","$PKG_FILENAME"}
    if [ "$?" -ne "$EXIT_SUCCESS" ]
    then
        echo "${ERR_COLOR}error:${NO_COLOR} failed to remove artifacts"
    else
        echo "Done."
    fi

    exit "$EXIT_SUCCESS"
}

main
