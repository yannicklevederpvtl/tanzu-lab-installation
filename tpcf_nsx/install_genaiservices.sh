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

remote::downloadTanzuNetServicesPackages \
  "$tanzu_net_api_token" \
  "$opsman_version" \
  "$tas_version" \
  "$install_genai" \
  "$genai_version" \
  "$install_postgres" \
  "$postgres_version" \

remote::configureAndDeployPostgres \
 "$opsman_host" \
 "'$om_password'" \
 "$postgres_version" \
 "$tcp_fqdn"

remote::configureAndDeployGenAI \
  "$opsman_host" \
  "'$om_password'" \
  "$genai_version"

echo 
echo "Fin"