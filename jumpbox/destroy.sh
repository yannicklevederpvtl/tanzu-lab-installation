#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=common/local.sh
source ../common/local.sh

loadJumpboxConfig

# Prereqs
: "${vcenter_password?Must provide a vcenter_password env var}"

# Defaults
: "${vcenter_host:=vc01.${homelab_domain}}"
: "${vm_name:=jumpbox}"
: "${vcenter_username:=administrator@vsphere.local}"

# Setup govc creds n' stuff
export \
  GOVC_INSECURE=1 \
  GOVC_USERNAME="${vcenter_username}" \
  GOVC_PASSWORD="${vcenter_password}" \
  GOVC_URL="${vcenter_host}"

# Ensure govc is installed
checkLocalPrereqs

# delete VM and disks
govc vm.destroy \
  "${vm_name}" \
