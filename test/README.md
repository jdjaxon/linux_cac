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

# rerun cac_setup.sh and tests only
vagrant provision ubuntu2404 --provision-with cac_setup,test

# wipe clean
vagrant destroy
```
