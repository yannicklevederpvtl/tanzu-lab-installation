#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=common/local.sh
source ../common/local.sh

# shellcheck source=common/install.sh
source ../common/install.sh

# shellcheck source=common/opsman.sh
source ../common/tas.sh

# shellcheck source=common/opsman.sh
source ../common/opsman.sh

loadJumpboxConfig
loadConfig "tas.config"

# Defaults
: "${opsman_host:=opsman.${tas_subdomain}.${homelab_domain}}"
: "${install_hubcollector:=false}"
: "${hubcollector_version:=10.2.2}"

remote::downloadTanzuNetHubCollectorPackage \
  "$tanzu_net_api_token" \
  "$hubcollector_version" 

remote::configureAndDeployHubCollector \
 "$opsman_host" \
 "'$om_password'" \
 "$hubcollector_version"