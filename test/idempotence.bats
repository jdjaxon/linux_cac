#!/usr/bin/env bats

# idempotence.bats
# Description: non-mutating tests for a second run of cac_setup.sh to ensure it
#              succeeds and converges on the same state as the first

. "${BATS_TEST_DIRNAME}/common.sh"

@test "second cac_setup.sh run exited successfully" {
  run cat "${EXIT_CODE_FILE}_2"
  [ "$status" -eq 0 ]
  if [ "$output" != "0" ]; then
    echo "second run of cac_setup.sh exited ${output}"
    return 1
  fi
}

@test "state is unchanged after the second run" {
  local snapshot
  for snapshot in "$STATE_FILE" "${STATE_FILE}_2"; do
    if [ ! -s "$snapshot" ]; then
      echo "missing snapshot ${snapshot}; run the cac_setup and cac_setup_rerun provisioners first"
      return 1
    fi
  done

  run diff "$STATE_FILE" "${STATE_FILE}_2"
  if [ "$status" -ne 0 ]; then
    echo "state differs between runs (< first run, > second run):"
    echo "$output"
    return 1
  fi
}

@test "PKCS11 module registered exactly once in Firefox" {
  local profile
  profile=$(ff_profile)
  [ -n "$profile" ]

  [ "$(cac_module_count "$profile")" -eq 1 ]
}

@test "PKCS11 module registered exactly once in Chrome" {
  [ "$(cac_module_count "$(chrome_profile)")" -eq 1 ]
}

@test "pcscd.socket still enabled after the second run" {
  run systemctl is-enabled pcscd.socket
  [ "$status" -eq 0 ]
}
