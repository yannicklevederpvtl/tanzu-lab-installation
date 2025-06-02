#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=common/local.sh
source ../common/local.sh

# shellcheck source=common/install.sh
source ../common/install.sh

# shellcheck source=tas/tas.sh
source ./tas.sh

# shellcheck source=common/opsman.sh
source ../common/opsman.sh

loadJumpboxConfig
loadConfig "tas.config"

# Defaults
: "${tcp_fqdn:=tcp.${tas_subdomain}.${homelab_domain}}"
: "${opsman_host:=opsman.${tas_subdomain}.${homelab_domain}}"
: "${install_tkgi:=false}"
: "${tkgi_api_host:=tkgi-api.${tas_subdomain}.${homelab_domain}}"

remote::downloadTanzuNetHealthwatchPackages \
  "$tanzu_net_api_token" \
  "$opsman_version" \
  "$tas_version" \
  "$install_healthwatch" \
  "$healthwatch_version" \
  "$install_tkgi" \
  "$install_genai"

remote::configureAndDeployHealthwatch \
 "$opsman_host" \
 "'$om_password'" \
 "$healthwatch_version" \
 "$install_tkgi" \
 "$install_genai"
