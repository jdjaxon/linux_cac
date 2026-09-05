#!/usr/bin/env bash

# run_cac_setup.sh
# Description: run cac_setup.sh and record its exit code alongside a snapshot of
#              the state it owns, so two runs can be compared for idempotency.
# Usage: run_cac_setup.sh [suffix]
#        the suffix distinguishes runs: "" for the first, "_2" for the rerun.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$TEST_DIR")"

# shellcheck source=test/common.sh
. "$TEST_DIR/common.sh"

suffix="${1:-}"

# deliberately not aborting on failure: the recorded exit code is the assertion
SUDO_USER="$TARGET_USER" bash "$REPO_ROOT/cac_setup.sh"
echo $? > "${EXIT_CODE_FILE}${suffix}"

bash "$TEST_DIR/cac_state.sh" > "${STATE_FILE}${suffix}"
