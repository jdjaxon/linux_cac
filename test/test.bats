#!/usr/bin/env bats

# test.bats
# Description: tests for cac_setup.sh

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

ff_profile() {
  find /home/vagrant -name "cert9.db" 2>/dev/null \
    | grep "firefox" | grep -v "Trash" \
    | head -1 | xargs -I{} dirname {}
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "cac_setup.sh exited successfully" {
  run cat /tmp/cac_setup_exit_code
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

  run modutil -dbdir sql:${profile} -list 2>&1
  [ "$status" -eq 0 ]

  # Snap path:     "CAC Module"
  # Non-snap path: "OpenSC smartcard framework" (name set by pkcs11-register)
  echo "$output" | grep -qi "CAC Module\|OpenSC"
}

@test "DoD certificates imported into Firefox profile" {
  local profile cert_count
  profile=$(ff_profile)
  [ -n "$profile" ]

  cert_count=$(certutil -d "sql:${profile}" -L 2>/dev/null | grep -c '\.cer' || echo 0)
  # arbitrary number
  [ "$cert_count" -gt 10 ]
}
