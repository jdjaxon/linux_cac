#!/usr/bin/env bash

# cac_setup.sh
#
# Author: Jeremy Jackson
# Date: 24 Feb 2022
# Description: Setup a Linux environment for Common Access Card use.
# References:
#   1. https://tldp.org/LDP/abs/html/sha-bang.html

DWNLD_DIR=/tmp
ROOT_UID=0      # Only users with $UID 0 have root privileges
E_NOTROOT=87    # Non-root exit error
CERT_FILENAME="AllCerts"
BUNDLE_FILENAME="AllCerts.zip"
CERT_URL="http://militarycac.com/maccerts/$BUNDLE_FILENAME"
PKG_FILENAME="cackey_0.7.5-1_amd64.deb"
CACKEY_URL="http://cackey.rkeene.org/download/0.7.5/$PKG_FILENAME"

# Ensure the script is ran as root
# TODO uncomment
#if [ "$UID" -ne "$ROOT_UID" ]
#then
    #echo "Please run this script as root."
    #exit $E_NOTROOT
#fi

# Install middleware and necessary utilities
# TODO uncomment
#echo "Installing middleware..."
#apt update
#apt install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools wget unzip
#echo "Done"

# Pull all necessary files
echo -e "Downloading DoD certificates and Cackey package...\n"
wget -P $DWNLD_DIR $CERT_URL
wget -P $DWNLD_DIR $CACKEY_URL
echo -e "Done\n"

# Unzip cert bundle
mkdir -p $DWNLD_DIR/$CERT_FILENAME
unzip $DWNLD_DIR/$BUNDLE_FILENAME -d $DWNLD_DIR/$CERT_FILENAME

# Removed artifacts
echo -e "Removing artifacts...\n"
rm -rf $DWNLD_DIR/{$BUNDLE_FILENAME,$CERT_FILENAME,$PKG_FILENAME}
echo -e "Done\n"

# Locate Firefox's database directory in the user's profile
FirefoxCertDir=$(dirname $(find $HOME/.mozilla -name cert*.db))
echo "Firefox DB: $FirefoxCertDir"

exit 0
