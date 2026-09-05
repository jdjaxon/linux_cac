#!/usr/bin/env bats

# test.bats
# Description: tests for cac_setup.sh

. "${BATS_TEST_DIRNAME}/common.sh"

@test "cac_setup.sh exited successfully" {
  run cat "$EXIT_CODE_FILE"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "pcscd.socket enabled" {
  run systemctl is-enabled pcscd.socket
  [ "$status" -eq 0 ]
}

@test "pcscd.socket starts cleanly" {
  systemctl start pcscd.socket
  run systemctl is-active pcscd.socket
  [ "$status" -eq 0 ]
}

@test "PKCS11 module registered in Firefox" {
  local profile
  profile=$(ff_profile)
  [ -n "$profile" ]

  [ "$(cac_module_count "$profile")" -gt 0 ]
}

@test "DoD certificates imported into Firefox profile" {
  local profile
  profile=$(ff_profile)
  [ -n "$profile" ]

  # arbitrary number
  [ "$(cert_count "$profile")" -gt 10 ]
}

@test "PKCS11 module registered in Chrome" {
  [ "$(cac_module_count "$(chrome_profile)")" -gt 0 ]
}

@test "DoD certificates imported into Chrome profile" {
  [ "$(cert_count "$(chrome_profile)")" -gt 10 ]
}
