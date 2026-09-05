#!/usr/bin/env bash

# cac_state.sh
# Description: dump every piece of state cac_setup.sh owns, in a stable order,
#              so that two runs of the script can be diffed against each other

TARGET_HOME="${TARGET_HOME:-/home/vagrant}"
DB_FILENAME="cert9.db"
CHROME_NSSDB="${TARGET_HOME}/.local/share/pki/nssdb"
DWNLD_DIR="/tmp"
BUNDLE_FILENAME="AllCerts.zip"
CERT_FILENAME="AllCerts"


# Locate the Firefox profile directory holding the NSS database
ff_profile ()
{
    find "$TARGET_HOME" -name "$DB_FILENAME" 2>/dev/null \
        | grep "firefox" | grep -v "Trash" \
        | head -1 | xargs -I{} dirname {}
} # ff_profile


# dump the PKCS11 modules and certificates of a single NSS database directory
dump_nssdb ()
{
    local db_dir="$1"

    echo "== ${db_dir} modules"
    # numbered module names plus the library each resolves to; the rest of the
    # table is padding, uris and slot state that need not match between runs
    modutil -dbdir "sql:${db_dir}" -list 2>&1 \
        | grep -E '^[[:space:]]*([0-9]+\.|library name:)' \
        | sed 's/^[[:space:]]*//'

    echo "== ${db_dir} certs"
    certutil -d "sql:${db_dir}" -L 2>&1 | sort
} # dump_nssdb


main ()
{
    local db_dir artifact

    echo "== pcscd.socket enabled: $(systemctl is-enabled pcscd.socket 2>&1)"

    for db_dir in "$(ff_profile)" "$CHROME_NSSDB"
    do
        if [ -n "$db_dir" ] && [ -d "$db_dir" ]
        then
            dump_nssdb "$db_dir"
        fi
    done

    # the script is expected to clean up after itself on every run
    echo "== artifacts"
    for artifact in "$DWNLD_DIR/$BUNDLE_FILENAME" "$DWNLD_DIR/$CERT_FILENAME"
    do
        if [ -e "$artifact" ]
        then
            echo "${artifact}: present"
        else
            echo "${artifact}: absent"
        fi
    done
} # main


main
