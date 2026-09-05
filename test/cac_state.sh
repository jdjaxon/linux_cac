#!/usr/bin/env bash

# cac_state.sh
# Description: dump every piece of state cac_setup.sh owns, in a stable order,
#              so that two runs of the script can be diffed against each other

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=test/common.sh
. "$TEST_DIR/common.sh"


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

    while read -r db_dir
    do
        dump_nssdb "$db_dir"
    done < <(nss_dbs)

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
