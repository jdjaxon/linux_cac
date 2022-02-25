#!/usr/bin/env bash

# cac_setup.sh
# Author: Jeremy Jackson
# Date: 24 Feb 2022
# Description: Setup a Linux environment for Common Access Card use.

main ()
{
    EXIT_SUCCESS=0     # Success exit code
    E_INSTALL=85       # Installation failed
    E_NOTROOT=86       # Non-root exit error
    ROOT_UID=0         # Only users with $UID 0 have root privileges
    DWNLD_DIR="/tmp"   # Reliable location to place artifacts

    CERT_EXTENSION="cer"
    NSSDB_FILENAME="cert9.db"
    CERT_FILENAME="AllCerts"
    BUNDLE_FILENAME="AllCerts.zip"
    CERT_URL="http://militarycac.com/maccerts/$BUNDLE_FILENAME"
    PKG_FILENAME="cackey_0.7.5-1_amd64.deb"
    CACKEY_URL="http://cackey.rkeene.org/download/0.7.5/$PKG_FILENAME"

    # Ensure the script is ran as root
    if [ "$UID" -ne "$ROOT_UID" ]
    then
        echo "Please run this script as root."
        exit "$E_NOTROOT"
    fi

    # Install middleware and necessary utilities
    echo "Installing middleware..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools unzip libnss3-tools
    echo "Done"

    # Pull all necessary files
    echo "Downloading DoD certificates and Cackey package..."
    wget -qP "$DWNLD_DIR" "$CERT_URL"
    wget -qP "$DWNLD_DIR" "$CACKEY_URL"
    echo "Done."

    # Install libcackey.
    echo "Installing libcackey..."
    if dpkg -i "$DWNLD_DIR/$PKG_FILENAME":w
    then
        echo "Done."
    else
        echo "error: installation failed. Exitting..."
        exit "$E_INSTALL"
    fi

    # Prevent cackey from upgrading
    # If cackey upgrades from 7.5 to 7.10, it moves libcackey.so to a different location
    # breaking Firefox.
    if apt-mark hold cackey
    then
        echo "Hold placed on cackey package."
    else
        echo "error: failed to place hold on cackey package."
    fi

    # Unzip cert bundle
    mkdir -p "$DWNLD_DIR/$CERT_FILENAME"
    unzip "$DWNLD_DIR/$BUNDLE_FILENAME" -d "$DWNLD_DIR/$CERT_FILENAME"

    # Check for Chrome
    if google-chrome --version
    then
        # Locate Firefox's database directory in the user's profile
        if ChromeCertDB=$(dirname "$(find "$HOME"/.pki -name "$NSSDB_FILENAME")")
        then
            # Import DoD certificates
            echo "Importing DoD certificates for Chrome..."
            for cert in "$DWNLD_DIR/$CERT_FILENAME/"*."$CERT_EXTENSION"
            do
                certutil -d sql:"$ChromeCertDB" -A -t TC -n "$cert" -i "$cert"
            done
            echo "Done."
        else
            echo "error: unable to find Chromes's certificate database"
        fi
    fi

    # Check for Firefox
    if firefox --version
    then
        # Locate Firefox's database directory in the user's profile
        if FirefoxCertDB=$(dirname "$(find "$HOME"/.mozilla -name "$NSSDB_FILENAME")")
        then
            # Import DoD certificates
            echo "Importing DoD certificates for Firefox..."
            for cert in "$DWNLD_DIR/$CERT_FILENAME/"*."$CERT_EXTENSION"
            do
                certutil -d sql:"$FirefoxCertDB" -A -t TC -n "$cert" -i "$cert"
            done
            echo "Done."
        else
            echo "error: unable to find Firefox's certificate database"
        fi
    fi

    # TODO: find a way to create a security module in Firefox from terminal

    # Remove artifacts
    echo "Removing artifacts..."
    rm -rf "${DWNLD_DIR:?}"/{"$BUNDLE_FILENAME","$CERT_FILENAME","$PKG_FILENAME"}
    if [ "$?" -ne "$EXIT_SUCCESS" ]
    then
        echo "error: failed to remove artifacts"
    else
        echo "Done."
    fi

    exit "$EXIT_SUCCESS"
}

main
