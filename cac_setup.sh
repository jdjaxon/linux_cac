#!/usr/bin/env bash

# cac_setup.sh
# Description: Setup a Linux environment for Common Access Card use.

# Bug fix (feedback #18): enable strict mode so failures of wget, apt, and
# unzip abort the script instead of being silently ignored. Without this, a
# failed download/extraction left the certificate glob unexpanded and certutil
# was invoked once per database with a literal '*' filename while the script
# still reported success.
set -euo pipefail

main ()
{
    EXIT_SUCCESS=0                      # Success exit code
    E_NOTROOT=86                        # Non-root exit error
    E_BROWSER=87                        # Browser-related error (e.g. no browser installed)
    E_DATABASE=88                       # No database located
    # Security (feedback #16): use a secure, unpredictable working directory
    # instead of a fixed path in world-writable /tmp. A predictable location
    # lets a local attacker pre-create AllCerts.zip or AllCerts/ as symlinks,
    # causing root-run wget/unzip to write through them (CWE-377/CWE-59).
    # 'mktemp -d' creates a private (0700) directory owned by root.
    DWNLD_DIR="$(mktemp -d)"
    trap 'rm -rf "$DWNLD_DIR"' EXIT     # Always clean up artifacts on any exit path

    chrome_exists=false                 # Google Chrome is installed
    ff_exists=false                     # Firefox is installed
    snap_ff=false                       # Snapped Firefox
    ff_profile_dir=""                   # Firefox profile directory

    ORIG_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    CERT_EXTENSION="cer"
    # PKCS_FILENAME="pkcs11.txt"
    DB_FILENAME="cert9.db"
    CERT_FILENAME="AllCerts"
    BUNDLE_FILENAME="AllCerts.zip"
    CERT_URL="https://militarycac.com/maccerts/$BUNDLE_FILENAME"

    # Security (feedback #17): pin the SHA256 digest of the certificate bundle.
    # MAINTAINERS: this pin was recorded from militarycac.com/maccerts/AllCerts.zip
    # on 2026-08-23 (Last-Modified: Tue, 01 Apr 2025 01:55:12 GMT). It is a
    # best-effort integrity reference, not an authoritative trust anchor — it
    # was computed from the same server the script downloads from, so it can
    # detect corruption or mirror drift but cannot prove authenticity on its
    # own. Update whenever upstream legitimately changes.
    EXPECTED_BUNDLE_SHA256="b07b90789c2f39db77ca26a30926851a708ee615f2235235f09867841badfacc"
    EXPECTED_BUNDLE_SHA256_DATE="2026-08-23"

    root_check
    browser_check
    mapfile -t databases < <(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox\|pki" | grep -v "Trash")
    # Check if databases were found properly
    if [ "${#databases[@]}" -eq 0 ]
    then
        print_warn "No valid databases located. Try running, then closing Firefox, then start this script again."
        print_warn "Continuing without importing certificates into any browser profile."
        SKIP_CERT_IMPORT=true
    fi

    # Install middleware and necessary utilities
    print_info "Installing middleware and essential utilities..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools libnss3-tools unzip wget opensc
    print_info "Done"

    # Pull all necessary files
    print_info "Downloading DoD certificates..."
    if ! wget -qP "$DWNLD_DIR" "$CERT_URL"
    then
        print_warn "Failed to download $CERT_URL"
    fi

    if [ ! -e "$DWNLD_DIR/$BUNDLE_FILENAME" ]
    then
        print_warn "$BUNDLE_FILENAME was not found in $DWNLD_DIR after downloading."
        print_info "Check your network connection and the URL: $CERT_URL"
        print_warn "Continuing without the certificate bundle (nothing will be imported)."
        SKIP_CERT_IMPORT=true
    fi
    print_info "Done."

    # Security (feedback #17): verify the bundle's integrity BEFORE any of its
    # contents are unzipped or imported with trust flags ('-t TC'). A missing
    # pinned digest is a warning the user can proceed past; a checksum mismatch
    # against a configured digest is also a warning (the user may still proceed,
    # but is informed of the risk). Either way the script continues so the user
    # can make an informed decision rather than being force-stopped.
    ACTUAL_BUNDLE_SHA256="$(sha256sum "$DWNLD_DIR/$BUNDLE_FILENAME" 2>/dev/null | awk '{print $1}')"

    if [ -z "$EXPECTED_BUNDLE_SHA256" ]
    then
        print_warn "No pinned SHA256 digest configured for $BUNDLE_FILENAME."
        print_warn "The bundle was not verified against a trusted value."
        print_info "Current SHA256: ${ACTUAL_BUNDLE_SHA256:-<unreadable>}"
        print_info "Compare this digest against the value published with the release notes"
        print_info "(or https://public.cyber.mil/pki-pke/) before trusting these certificates."
    elif [ "$ACTUAL_BUNDLE_SHA256" != "$EXPECTED_BUNDLE_SHA256" ]
    then
        print_warn "SHA256 mismatch for $BUNDLE_FILENAME — continuing anyway at the user's own risk."
        print_warn "Pinned (${EXPECTED_BUNDLE_SHA256_DATE:-date unknown}): $EXPECTED_BUNDLE_SHA256"
        print_warn "Actual:   ${ACTUAL_BUNDLE_SHA256:-<file missing or unreadable>}"
        print_info "The upstream bundle may have been legitimately updated, or the download"
        print_info "may be corrupted or tampered with. Verify against"
        print_info "https://public.cyber.mil/pki-pke/ before trusting these certificates."
    else
        print_info "Bundle integrity verified against pin dated ${EXPECTED_BUNDLE_SHA256_DATE:-unknown} (${ACTUAL_BUNDLE_SHA256})."
    fi

    # Unzip cert bundle
    if [ ! -e "$DWNLD_DIR/$BUNDLE_FILENAME" ]
    then
        # Download failed: warn and skip extraction/import rather than aborting.
        print_warn "$BUNDLE_FILENAME is missing from $DWNLD_DIR; skipping certificate import."
        SKIP_CERT_IMPORT=true
    elif ! unzip "$DWNLD_DIR/$BUNDLE_FILENAME" -d "$DWNLD_DIR/$CERT_FILENAME"
    then
        print_warn "Failed to extract $BUNDLE_FILENAME."
        print_warn "Continuing WITHOUT imported certificates."
        SKIP_CERT_IMPORT=true
    fi

    if [ "${SKIP_CERT_IMPORT:-false}" != true ]
    then
    # Import certificates into cert9.db databases for browsers
    for db in "${databases[@]}"
    do
        if [ -n "$db" ]
        then
            import_certs "$db"
        fi
    done
    else
        print_warn "Skipping certificate import (no usable bundle)."
    fi

    print_info "Enabling pcscd service to start on boot..."
    systemctl enable pcscd.socket
    print_info "Done"

    # Handle snapped firefox
    if [ "$snap_ff" == true ]
    then
        print_info "Connecting snapped Firefox to the pcscd socket..."
        if ! snap connect firefox:pcscd
        then
            print_warn "Failed to connect. Try upgrading with 'apt upgrade' and 'snap refresh' first."
            print_warn "Continuing without the pcscd snap connection."
        fi

        print_info "Registering the pkcs11 module..."
        sudo -H -u "$SUDO_USER" modutil -dbdir "sql:$ff_profile_dir" \
            -add "CAC Module" -libfile /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so -force
    else
        print_info "Registering CAC module with PKSC11..."
        pkcs11-register
        print_info "Done"

        # NOTE: Keeping this temporarily to test `pkcs11-register`.
        # if ! grep -Pzo 'library=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so\nname=CAC Module\n' "$db_root/$PKCS_FILENAME" >/dev/null
        # then
        #     printf "library=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so\nname=CAC Module\n" >> "$db_root/$PKCS_FILENAME"
        # fi
    fi


    # Remove artifacts
    print_info "Removing artifacts..."
    rm -rf "${DWNLD_DIR:?}"/{"$BUNDLE_FILENAME","$CERT_FILENAME"} 2>/dev/null
    if [ "$?" -ne "$EXIT_SUCCESS" ]
    then
        print_warn "Failed to remove some artifacts. The EXIT trap will remove ${DWNLD_DIR}."
    else
        print_info "Done. A reboot may be required."
    fi

    exit "$EXIT_SUCCESS"
} # main


# Prints message with red [ERROR] tag before the message
print_err ()
{
    ERR_COLOR='\033[0;31m'  # Red for error messages
    NO_COLOR='\033[0m'      # Revert terminal back to no color
    echo -e "${ERR_COLOR}[ERROR]${NO_COLOR} $1"
} # print_err


# Prints message with yellow [INFO] tag before the message
print_info ()
{
    INFO_COLOR='\033[0;33m' # Yellow for notes
    NO_COLOR='\033[0m'      # Revert terminal back to no color
    echo -e "${INFO_COLOR}[INFO]${NO_COLOR} $1"
} # print_info


# Prints message with yellow [WARN] tag before the message
print_warn ()
{
    WARN_COLOR='\033[0;33m' # Yellow for warnings
    NO_COLOR='\033[0m'      # Revert terminal back to no color
    echo -e "${WARN_COLOR}[WARN]${NO_COLOR} $1"
} # print_warn


# Check to ensure the script is executed as root
root_check ()
{
    # Only users with $UID 0 have root privileges
    local ROOT_UID=0

    # Ensure the script is ran as root
    if [ "${EUID:-$(id -u)}" -ne "$ROOT_UID" ]
    then
        print_err "This script must run as root to install packages and import trusted certificates."
        print_warn "Re-run with sudo. Aborting to avoid partial privilege-unsafe state."
        exit "$E_NOTROOT"
    fi
} # root_check


# Run Firefox to ensure the profile directory has been created
run_firefox ()
{
    print_info "Starting Firefox silently to complete post-install actions..."
    sudo -H -u "$SUDO_USER" firefox --headless --first-startup >/dev/null 2>&1 &
    FF_PID=$!
    sleep 3
    # Bug fix (feedback #19): terminate only the Firefox instance this script
    # spawned, escalating SIGTERM -> SIGKILL. A root-run 'pkill -9 firefox'
    # kills every matching process on the system (including other users'
    # active sessions) and skips NSS SQLite checkpointing, risking corruption
    # of the cert9.db databases this script depends on.
    stop_browser "$FF_PID"
    sleep 1
} # run_firefox


# Bug fix (feedback #19): stop a browser process spawned by this script using
# its PID instead of a global root 'pkill -9 <browser>', which would kill every
# matching process on the system (including other users' active sessions).
# SIGTERM is sent first so the browser can shut down cleanly and NSS can
# checkpoint its SQLite databases (cert9.db); SIGKILL is used only as a last
# resort after a grace period.
stop_browser ()
{
    local pid=$1
    local waited=0
    local GRACE_SECONDS=10

    if kill -0 "$pid" 2>/dev/null
    then
        kill -TERM "$pid" 2>/dev/null || true

        while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$GRACE_SECONDS" ]
        do
            sleep 1
            waited=$((waited + 1))
        done

        # Escalate to SIGKILL only if the process refused to terminate
        if kill -0 "$pid" 2>/dev/null
        then
            kill -KILL "$pid" 2>/dev/null || true
        fi
    fi
} # stop_browser


# Run Chrome to ensure .pki directory has been created
run_chrome ()
{
    # NOTE: this is the original
    # sudo -H -u "$SUDO_USER" bash -c 'google-chrome --headless --disable-gpu >/dev/null 2>&1 &'

    # TODO: finish troubleshooting this
    print_info "Running Chrome to ensure it has completed post-install actions..."
    sudo -H -u "$SUDO_USER" google-chrome --headless --disable-gpu >/dev/null 2>&1 &
    CHROME_PID=$!
    sleep 3
    # Bug fix (feedback #19): terminate only the Chrome instance this script
    # spawned, escalating SIGTERM -> SIGKILL (see stop_browser).
    stop_browser "$CHROME_PID"
    sleep 1
    print_info "Done."
} # run_chrome


# Discovery of browsers installed on the user's system
# Sets appropriate flags to control the flow of the installation, depending on
# what is needed for the individual user
browser_check ()
{
    print_info "Checking for Firefox and Chrome..."
    check_for_firefox
    check_for_chrome

    # Browser check results
    if [ "$ff_exists" == false ] && [ "$chrome_exists" == false ]
    then
        print_warn "No version of Mozilla Firefox OR Google Chrome has been detected."
        print_warn "Certificate import will be skipped for browsers (none were found). Continuing with middleware install."
    fi
} # browser_check


# Attempt to find an installed version of Firefox on the user's system
# Determines whether the version is installed via snap or apt
check_for_firefox ()
{
    if command -v firefox >/dev/null
        then
            # Run Firefox to ensure .mozilla directory has been created
            print_info "Running Firefox to generate profile directory..."
            run_firefox
            print_info "Done."

            ff_exists=true
            db_location="$(find "$ORIG_HOME" -name "$DB_FILENAME" 2>/dev/null | grep "firefox" | grep -v "Trash")"
            ff_profile_dir="$(dirname "$db_location")"
            print_info "Found Firefox with profile in ${ff_profile_dir}"

            if command -v firefox | grep snap >/dev/null
            then
                snap_ff=true
                print_info "This version of Firefox was installed as a snap package"
            elif command -v firefox | xargs grep -Fq "exec /snap/bin/firefox"
            then
                snap_ff=true
                print_info "This version of Firefox was installed as a snap package with a launch script"
            else
                print_info "This is not a snap-installed version of Firefox."
            fi
        else
            print_info "Firefox not found."
        fi
} # check_for_firefox


# Attempt to find a version of Google Chrome installed on the user's system
check_for_chrome ()
{
    # Check to see if Chrome exists
    if command -v google-chrome >/dev/null
    then
        chrome_exists=true
        print_info "Found Google Chrome."
        # Run Chrome to ensure .pki directory has been created
        run_chrome
    else
        print_info "Chrome not found."
    fi
} # check_for_chrome


# Integrate all certificates into the databases for existing browsers
import_certs ()
{
    db=$1
    db_root="$(dirname "$db")"
    if [ -n "$db_root" ]
    then
        case "$db_root" in
            *"pki"*)
                print_info "Importing certificates for Chrome..."
                echo
                ;;
            *"firefox"*)
                print_info "Importing certificates for Firefox..."
                echo
                ;;
        esac

        print_info "Loading certificates into $db_root "
        echo

        # Bug fix (feedback #18): guard the glob so certutil is never invoked
        # with a literal '*' filename, and fail clearly when no certificates
        # were extracted at all.
        local cert_count=0
        for cert in "$DWNLD_DIR/$CERT_FILENAME/"*."$CERT_EXTENSION"
        do
            [ -e "$cert" ] || continue
            echo "Importing $cert"
            certutil -d sql:"$db_root" -A -t TC -n "$cert" -i "$cert"
            cert_count=$((cert_count + 1))
        done

        if [ "$cert_count" -eq 0 ]
        then
            print_warn "No .$CERT_EXTENSION certificates found in $DWNLD_DIR/$CERT_FILENAME."
            print_warn "Skipping import for $db_root (no certificates to import)."
            return "$EXIT_SUCCESS"
        fi
    fi

    print_info "Done."
    echo
} # import_certs


main
