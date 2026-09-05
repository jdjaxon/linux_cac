# Integration testing

Vagrant-based testing for the `cac_setup.sh` script.

## Overview

The goal is to alleviate testing across various distributions. This solution is
not ideal as it's impractical to integrate into a CI/CD pipeline without custom
runners; however, it should suffice to conveniently provide a fair measure of
assurance that the script functions as intended across a set of given
distribution versions.

## Prerequisites

- vagrant
- a VM provider, one of:
  - virtualbox
  - libvirt + qemu-kvm (system `libvirtd` running, user in `libvirt` group, the
    `vagrant-libvirt` plugin)
- `genisoimage` or whichever package provides `mkisofs`
- web connectivity

## Usage

```bash
# run all VMs (uses vagrant's default provider)
vagrant up

# use libvirt instead of the default provider
vagrant up --provider=libvirt
# or persist the choice for the session
export VAGRANT_DEFAULT_PROVIDER=libvirt

# run a specific VM
vagrant up ubuntu2404

# push local edits to a running VM first: the libvirt provider syncs
# /vagrant_root with rsync, so `vagrant provision` alone runs stale files
vagrant rsync ubuntu2404

# rerun cac_setup.sh and tests only
vagrant provision ubuntu2404 --provision-with cac_setup,test

# rerun only the idempotency phase against an already-provisioned VM
vagrant provision ubuntu2404 --provision-with cac_setup_rerun,test_idempotence

# wipe clean
vagrant destroy
```

## Phases

Each VM is provisioned in six steps, each runnable on its own via
`--provision-with`:

| Provisioner        | What it does                                              |
| ------------------ | --------------------------------------------------------- |
| `pre_setup`        | installs Firefox and Chrome                                |
| `install_bats`     | installs bats                                              |
| `cac_setup`        | `run_cac_setup.sh` — runs `cac_setup.sh`, records its exit code and a snapshot of the state it owns (`cac_state.sh`) |
| `test`             | runs `test.bats` against that state                        |
| `cac_setup_rerun`  | `run_cac_setup.sh _2` — the same, a second time, recorded under a `_2` suffix |
| `test_idempotence` | runs `idempotence.bats`, which diffs the two snapshots      |
