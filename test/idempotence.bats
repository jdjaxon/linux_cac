#!/usr/bin/env bats

# idempotence.bats
# Description: non-mutating tests for a second run of cac_setup.sh to ensure it
#              succeeds and converges on the same state as the first

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

ff_profile() {
  find /home/vagrant -name "cert9.db" 2>/dev/null \
    | grep "firefox" | grep -v "Trash" \
    | head -1 | xargs -I{} dirname {}
}

chrome_profile() {
  echo "/home/vagrant/.local/share/pki/nssdb"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "second cac_setup.sh run exited successfully" {
  run cat /tmp/cac_setup_exit_code_2
  [ "$status" -eq 0 ]
  if [ "$output" != "0" ]; then
    echo "second run of cac_setup.sh exited ${output}"
    return 1
  fi
}

@test "state is unchanged after the second run" {
  local snapshot
  for snapshot in /tmp/cac_state /tmp/cac_state_2; do
    if [ ! -s "$snapshot" ]; then
      echo "missing snapshot ${snapshot}; run the cac_setup and cac_setup_rerun provisioners first"
      return 1
    fi
  done

  run diff /tmp/cac_state /tmp/cac_state_2
  if [ "$status" -ne 0 ]; then
    echo "state differs between runs (< first run, > second run):"
    echo "$output"
    return 1
  fi
}

@test "PKCS11 module registered exactly once in Firefox" {
  local profile count
  profile=$(ff_profile)
  [ -n "$profile" ]

  count=$(modutil -dbdir "sql:${profile}" -list 2>&1 | grep -c "CAC Module" || true)
  [ "$count" -eq 1 ]
}

@test "PKCS11 module registered exactly once in Chrome" {
  local count
  count=$(modutil -dbdir "sql:$(chrome_profile)" -list 2>&1 | grep -c "CAC Module" || true)
  [ "$count" -eq 1 ]
}

@test "pcscd.socket still enabled after the second run" {
  run systemctl is-enabled pcscd.socket
  [ "$status" -eq 0 ]
}
