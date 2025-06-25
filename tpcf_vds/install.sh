#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=common/local.sh
source ../common/local.sh

# shellcheck source=common/install.sh
source ../common/install.sh

# shellcheck source=common/opsman.sh
source ../common/opsman.sh

# shellcheck source=common/tas.sh
source ../common/tas.sh

# shellcheck source=tas/tasvds.sh
source ./tasvds.sh

loadJumpboxConfig
loadConfig "tas.config"

# Prereqs
: "${homelab_domain?Must provide a homelab_domain env var}"
: "${vcenter_host?Must provide a vcenter_host env var}"
: "${vcenter_username?Must provide a vcenter_username env var}"
: "${vcenter_password?Must provide a vcenter_password env var}"
: "${vcenter_datacenter?Must provide a vcenter_datacenter env var}"
: "${vcenter_cluster?Must provide a vcenter_cluster env var}"
: "${vm_network?Must provide a vm_network env var}"
: "${datastore?Must provide a datastore env var}"

# Prereqs from tas.config
: "${tanzu_net_api_token?Must provide a tanzu_net_api_token env var}"
: "${opsman_private_ip?Must provide a opsman_private_ip env var}"
: "${gorouter_ip_range?Must provide a gorouter_ip_range env var}"
: "${ssh_ip_range?Must provide a ssh_ip_range env var}"
: "${tcp_ip_range?Must provide a tcp_ip_range env var}"

# Defaults
: "${vcenter_host:=vcenter.${homelab_domain}}"
: "${opsman_host:=opsman.${tas_subdomain}.${homelab_domain}}"
: "${apps_domain:=apps.${tas_subdomain}.${homelab_domain}}"
: "${sys_domain:=sys.${tas_subdomain}.${homelab_domain}}"
: "${tcp_fqdn:=tcp.${tas_subdomain}.${homelab_domain}}"
: "${install_full_tas:=false}"
: "${install_tasw:=false}"
: "${xenial_stemcell_version:=621.897}"
: "${jammy_stemcell_version:=1.719}"
: "${windows_stemcell_version:=2019.71}"
: "${opsman_version:=3.0.37+LTS-T}"
: "${tas_version:=10.0.2}"
: "${tas_licensekey:=xxxx-xxxx-xxxx-xxxx}"

# Pick a linux stemcell based off TAS version
linux_stemcell_name='jammy'
linux_stemcell_version="$jammy_stemcell_version"
if [[ "$tas_version" =~ ^2\.11.* ]] || [[ "$tas_version" =~ ^2.12.* ]] || [[ "$tas_version" =~ ^2.13.* ]]; then
  linux_stemcell_name='xenial'
  linux_stemcell_version="$xenial_stemcell_version"
fi

declare -A hosts

tas_lb_web_virtual_server_ip_address="$(echo $gorouter_ip_range | awk -F'-' '{print $1}')"
tas_lb_tcp_virtual_server_ip_address="$(echo $tcp_ip_range | awk -F'-' '{print $1}')"
tas_lb_ssh_virtual_server_ip_address="$(echo $ssh_ip_range | awk -F'-' '{print $1}')"

hosts=(["*.apps"]="$tas_lb_web_virtual_server_ip_address" \
  ["*.sys"]="$tas_lb_web_virtual_server_ip_address" \
  ["tcp.apps"]="$tas_lb_tcp_virtual_server_ip_address" \
  ["ssh.sys"]="$tas_lb_ssh_virtual_server_ip_address" \
  ["opsman"]="$opsman_private_ip")

addDNSEntries "$homelab_domain" "$tas_subdomain" hosts

addHostToSSHConfig 'opsman' "$opsman_host" 'ubuntu'
createOpsmanDirEnv

remote::installTASTools
remote::downloadTanzuNetPackages \
 "$tanzu_net_api_token" \
 "$opsman_version" \
 "$tas_version" \
 "$linux_stemcell_name" \
 "$linux_stemcell_version" \
 "$windows_stemcell_version" \
 "$install_full_tas" \
 "$install_tasw"
remote::deployOpsman \
 "$vcenter_host" \
 "$vcenter_password" \
 "$opsman_version" \
 "$vcenter_pool" \
 "$infrastructure_network_identifier" \
 "$vcenter_username" \
 "$dns_servers" \
 "$ntp_servers" \
 "$vcenter_datacenter" \
 "$vcenter_cluster" \
 "$opsman_vm_name" \
 "$opsman_private_ip" \
 "$infrastructure_nat_gateway_ip" \
 "$vcenter_datastore"
remote::configureAndDeployBOSHvDS \
  "$vcenter_host" \
  "$opsman_host" \
  "'$om_password'" \
  "$vcenter_password" \
  "$vcenter_datacenter" \
  "$vcenter_cluster" \
  "$vcenter_pool" \
  "$vcenter_datastore" \
  "$infrastructure_network_identifier" \
  "$infrastructure_nat_gateway_ip" \
  "$infrastructure_cidr" \
  "$infrastructure_reserved_ip_ranges" \
  "$deployment_network_identifier" \
  "$deployment_nat_gateway_ip" \
  "$deployment_cidr" \
  "$deployment_reserved_ip_ranges" \
  "$services_network_identifier" \
  "$services_nat_gateway_ip" \
  "$services_cidr" \
  "$services_reserved_ip_ranges" \
  "$dns_servers" \
  "$ntp_servers" \
  "./director.yml"
remote::configureAndDeployTAS \
 "$opsman_host" \
 "'$om_password'" \
 "$sys_domain" \
 "$apps_domain" \
 "$tas_version" \
 "$linux_stemcell_name" \
 "$linux_stemcell_version" \
 "$install_full_tas" \
 "$install_tasw" \
 "$tas_licensekey"

addCFLoginToDirEnv "$sys_domain"

if $install_healthwatch; then
  remote::downloadTanzuNetHealthwatchPackages \
    "$tanzu_net_api_token" \
    "$opsman_version" \
    "$tas_version" \
    "$healthwatch_version" \
    "$install_tkgi" \
    "$install_genai"

  remote::configureAndDeployHealthwatch \
    "$opsman_host" \
    "'$om_password'" \
    "$healthwatch_version" \
    "$install_tkgi" \
    "$install_genai"
fi

echo
echo "SSH to ${opsman_host}:"
echo "  ssh -F ../jumpbox/.ssh/config opsman"
echo 
echo "List BOSH VMs:"
echo "  bosh vms"
echo 
echo "List Operations Manager tiles"
echo "  om products"
echo 
echo "Fin"