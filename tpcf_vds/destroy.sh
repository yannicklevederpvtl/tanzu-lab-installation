#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=common/local.sh
source ../common/local.sh

# shellcheck source=common/tas.sh
source ../common/tas.sh

# shellcheck source=tpcf_vds/tasvds.sh
source ./tasvds.sh

loadJumpboxConfig
loadConfig "tas.config"

: "${opsman_host:=opsman.${tas_subdomain}.${homelab_domain}}"

remote::deleteTASAndOpsman \
  "$opsman_host" \
  "'$om_password'" \
  "$opsman_vm_name" \
  "$vcenter_host" \
  "$vcenter_username" \
  "$vcenter_password"

 remote::deleteTanzuNetPackages
