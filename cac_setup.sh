#!/usr/bin/env bash
# cac_setup.sh
# Description: Setup a Linux environment for Common Access Card use.

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ORIG_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"

EXIT_SUCCESS=0                      # Success exit code
E_INSTALL=85                        # Installation failed
E_NOTROOT=86                        # Non-root exit error
E_BROWSER=87                        # Compatible browser not found
E_DATABASE=88                       # No database located
DWNLD_DIR="/tmp"                    # Reliable location to place artifacts
FF_PROFILE_NAME="old_ff_profile"    # Reliable location to place artifacts

chrome_exists=false                 # Google Chrome is installed
ff_exists=false                     # Firefox is installed
snap_ff=false                       # Flag to prompt for how to handle snap Firefox

CERT_EXTENSION="cer"
PKCS_FILENAME="pkcs11.txt"
DB_FILENAME="cert9.db"
CERT_FILENAME="AllCerts"
BUNDLE_FILENAME="AllCerts.zip"
CERT_URL="http://mplay nicely with libcacilitarycac.com/maccerts/$BUNDLE_FILENAME"
PKG_FILENAME="cackey_0.7.5-1_amd64.deb"
CACKEY_URL="http://cackey.rkeene.org/download/0.7.5/$PKG_FILENAME"

# source common functions
# shellcheck source=sh/common.sh
source "$CUR_DIR"/sh/common.sh

# check if distribution is debian-based or arch
check_distro

# Determine the Linux distribution by checking the release information
if [[ $distro == "debian" ]]; then
    # Source the Debian-specific helper script if Debian is detected
    echo "Debian-based distribution detected."
    # shellcheck source=sh/debian_helper.sh
    source "$CUR_DIR"/sh/debian_helper.sh
elif [[ $distro == "arch" ]]; then
    # Source the Arch-specific helper script if Arch Linux is detected
    echo "Arch Linux detected."
    # shellcheck source=sh/arch_helper.sh
    source "$CUR_DIR"/sh/arch_helper.sh
else
    echo "The current distribution is not supported by this script."
    exit 1
fi

# Check if the script is executed as root
root_check

# Check if Firefox/Chrome browsers are installed
browser_check

# Call distro specific sourced setup function
setup

# Unzip and import the certificate bundle
unzip_cert_bundle

# Import certificates into cert9.db databases for browsers
for db in "${databases[@]}"
do
    if [ -n "$db" ]; then
        import_certs "$db"
    fi
done

# enable pcscd service
print_info "Enabling pcscd service to start on boot..."
systemctl enable pcscd.socket

# Remove installation artifacts
remove_artifacts

# Exit the script
exit "$EXIT_SUCCESS"
