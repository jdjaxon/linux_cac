#!/usr/bin/env bash

# CITATION: https://tldp.org/LDP/abs/html/sha-bang.html

DWNLD_DIR=/tmp
ROOT_UID=0      # Only users with $UID 0 have root privileges
E_XCD=86        # Can't change directory
E_NOTROOT=87    # Non-root exit error

CERT_URL=http://militarycac.com/maccerts/AllCerts.zip
CACKEY_URL=http://cackey.rkeene.org/fossil/wiki?name=Downloads

# Ensure the script is ran as root
# TODO uncomment
#if [ "$UID" -ne "$ROOT_UID" ]
#then
    #echo "Please run this script as root."
    #exit $E_NOTROOT
#fi

# Install middleware
# TODO uncomment
#echo "Installing middleware..."
#apt install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools wget
#echo "Done"

