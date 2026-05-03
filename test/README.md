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
- virtualbox (other backends, e.g. QEMU, are possible but would require changes
  to the `Vagrantfile`)
- `genisoimage` or whichever package provides `mkisofs`
- web connectivity

## Usage

```bash
# run all VMs
vagrant up

# run a specific VM
vagrant up ubuntu2404

# rerun tests only
vagrant provision ubuntu2404 --provision-with test

# wipe clean
vagrant destroy
```
