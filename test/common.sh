#!/usr/bin/env bash

# common.sh
# Description: locations and queries shared by the test harness

# every constant below is read by a script or suite that sources this file
# shellcheck disable=SC2034

TARGET_USER="${TARGET_USER:-vagrant}"           # user cac_setup.sh provisions for
TARGET_HOME="${TARGET_HOME:-/home/$TARGET_USER}"
DB_FILENAME="cert9.db"                          # NSS database filename
DWNLD_DIR="/tmp"                                # where cac_setup.sh stages artifacts
BUNDLE_FILENAME="AllCerts.zip"
CERT_FILENAME="AllCerts"

# per-run records written by run_cac_setup.sh; callers append the run suffix
# ("" for the first run, "_2" for the rerun).
EXIT_CODE_FILE="/tmp/cac_setup_exit_code"
STATE_FILE="/tmp/cac_state"


# locate the Firefox profile directory holding the NSS database
ff_profile ()
{
    find "$TARGET_HOME" -name "$DB_FILENAME" 2>/dev/null \
        | grep "firefox" | grep -v "Trash" \
        | head -1 | xargs -I{} dirname {}
} # ff_profile


# Locate Chrome's NSS database directory
chrome_profile ()
{
    echo "$TARGET_HOME/.local/share/pki/nssdb"
} # chrome_profile


# emit each NSS database directory that exists, one per line
nss_dbs ()
{
    local db_dir

    for db_dir in "$(ff_profile)" "$(chrome_profile)"
    do
        if [ -n "$db_dir" ] && [ -d "$db_dir" ]
        then
            echo "$db_dir"
        fi
    done
} # nss_dbs


# count the PKCS11 modules named "CAC Module" in an NSS database directory
cac_module_count ()
{
    local db_dir="$1" count

    count=$(modutil -dbdir "sql:${db_dir}" -list 2>&1 | grep -c "CAC Module") || count=0
    echo "$count"
} # cac_module_count


# count the DoD certificates imported into an NSS database directory
cert_count ()
{
    local db_dir="$1" count

    count=$(certutil -d "sql:${db_dir}" -L 2>/dev/null | grep -c '\.cer') || count=0
    echo "$count"
} # cert_count
