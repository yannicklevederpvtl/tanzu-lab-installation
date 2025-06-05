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

# shellcheck source=tpcf_nsx/tas.sh
source ./tas.sh
# shellcheck source=tpcf_nsx/tkgi.sh
source ./tkgi.sh
loadJumpboxConfig
loadConfig "tas.config"

# Prereqs
: "${homelab_domain?Must provide a homelab_domain env var}"
: "${tas_subdomain?Must provide a tas_subdomain env var}"
: "${vcenter_host?Must provide a vcenter_host env var}"
: "${vcenter_username?Must provide a vcenter_username env var}"
: "${vcenter_password?Must provide a vcenter_password env var}"
: "${vcenter_datacenter?Must provide a vcenter_datacenter env var}"
: "${vcenter_cluster?Must provide a vcenter_cluster env var}"
: "${vm_network?Must provide a vm_network env var}"
: "${datastore?Must provide a datastore env var}"

# Prereqs from tas.config
: "${tanzu_net_api_token?Must provide a tanzu_net_api_token env var}"
: "${tas_infrastructure_nat_gateway_ip?Must provide a tas_infrastructure_nat_gateway_ip env var}"
: "${tas_deployment_nat_gateway_ip?Must provide a tas_deployment_nat_gateway_ip env var}"
: "${tas_services_nat_gateway_ip?Must provide a tas_services_nat_gateway_ip env var}"
: "${tas_ops_manager_public_ip?Must provide a tas_ops_manager_public_ip env var}"
: "${tas_lb_web_virtual_server_ip_address?Must provide a tas_lb_web_virtual_server_ip_address env var}"
: "${tas_lb_tcp_virtual_server_ip_address?Must provide a tas_lb_tcp_virtual_server_ip_address env var}"
: "${tas_lb_ssh_virtual_server_ip_address?Must provide a tas_lb_ssh_virtual_server_ip_address env var}"

# Defaults
: "${vcenter_host:=vcenter.${homelab_domain}}"
: "${nsxt_host:=nsxmanager.${homelab_domain}}"
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
: "${install_tkgi:=false}"
: "${tkgi_version:=1.21.0}"
: "${tkgi_nsxt_ingress_cidr:=10.90.0.0/24}"
: "${tkgi_nsxt_egress_cidr:=10.60.0.0/24}"
: "${tkgi_deployment_nat_gateway_ip=10.60.0.65}"
: "${tkgi_lb_api_virtual_server_ip_address=10.90.0.21}"
: "${tkgi_api_host:=tkgi-api.${tas_subdomain}.${homelab_domain}}"
: "${tkgi_clustergenai_lb_api_virtual_server_ip_address:=10.90.0.25}"
: "${tkgi_clustergenai_host:=tkgiclustergenai1.${tas_subdomain}.${homelab_domain}}"
: "${directorconfigfile:=./director.yml}"

# Pick a linux stemcell based off TAS version
linux_stemcell_name='jammy'
linux_stemcell_version="$jammy_stemcell_version"
if [[ "$tas_version" =~ ^2\.11.* ]] || [[ "$tas_version" =~ ^2.12.* ]] || [[ "$tas_version" =~ ^2.13.* ]]; then
  linux_stemcell_name='xenial'
  linux_stemcell_version="$xenial_stemcell_version"
fi

declare -A hosts

if $install_tkgi; then

hosts=(["*.apps"]="$tas_lb_web_virtual_server_ip_address" \
  ["*.sys"]="$tas_lb_web_virtual_server_ip_address" \
  ["tcp.apps"]="$tas_lb_tcp_virtual_server_ip_address" \
  ["ssh.sys"]="$tas_lb_ssh_virtual_server_ip_address" \
  ["opsman"]="$tas_ops_manager_public_ip" \
  ["tkgi-api"]="$tkgi_lb_api_virtual_server_ip_address")

directorconfigfile='./directortkgi.yml'
  
else

hosts=(["*.apps"]="$tas_lb_web_virtual_server_ip_address" \
  ["*.sys"]="$tas_lb_web_virtual_server_ip_address" \
  ["tcp.apps"]="$tas_lb_tcp_virtual_server_ip_address" \
  ["ssh.sys"]="$tas_lb_ssh_virtual_server_ip_address" \
  ["opsman"]="$tas_ops_manager_public_ip")

fi

addDNSEntries "$homelab_domain" "$tas_subdomain" hosts

addHostToSSHConfig 'opsman' "$opsman_host" 'ubuntu'
createOpsmanDirEnv

remote::installTASTools
remote::paveNSXT \
 "$nsxt_host" \
 "$nsxt_password" \
 "$tas_ops_manager_public_ip" \
 "$tas_lb_web_virtual_server_ip_address" \
 "$tas_lb_tcp_virtual_server_ip_address" \
 "$tas_lb_ssh_virtual_server_ip_address" \
 "$tas_infrastructure_nat_gateway_ip" \
 "$tas_deployment_nat_gateway_ip" \
 "$tas_services_nat_gateway_ip" \
 "$nsxt_username" \
 "'$nsxt_edgecluster_name'" \
 "'$nsxt_t0_gw_name'" \
 "'$nsxt_tz_name'" \
 "$install_tkgi" \
 "$tkgi_nsxt_ingress_cidr" \
 "$tkgi_nsxt_egress_cidr" \
 "$tkgi_lb_api_virtual_server_ip_address" \
 "$tkgi_deployment_nat_gateway_ip"
remote::downloadTanzuNetPackages \
 "$tanzu_net_api_token" \
 "$opsman_version" \
 "$tas_version" \
 "$linux_stemcell_name" \
 "$linux_stemcell_version" \
 "$windows_stemcell_version" \
 "$install_full_tas" \
 "$install_tasw" \
 "$install_tkgi" \
 "$tkgi_version" 
remote::deployOpsman \
 "$vcenter_host" \
 "$vcenter_password" \
 "$opsman_version" \
 "$vcenter_pool" \
 'tas-infra-segment' \
 "$vcenter_username" \
 "$dns_servers" \
 "$ntp_servers" \
 "$vcenter_datacenter" \
 "$vcenter_cluster" \
 "$opsman_vm_name" \
 "$opsman_private_ip" \
 "$opsman_gateway" \
 "$vcenter_datastore"
remote::configureAndDeployBOSH \
 "$vcenter_host" \
 "$nsxt_host" \
 "$opsman_host" \
 "'$om_password'" \
 "$vcenter_password" \
 "$nsxt_password" \
 "$vcenter_datacenter" \
 "$vcenter_cluster" \
 "$vcenter_pool" \
 "$vcenter_datastore" \
 "$dns_servers" \
 "$ntp_servers" \
 "$vcenter_username" \
 "$directorconfigfile"
remote::configureAndDeployTAS \
 "$opsman_host" \
 "'$om_password'" \
 "$sys_domain" \
 "$apps_domain" \
 "$tas_version" \
 "$linux_stemcell_name" \
 "$linux_stemcell_version" \
 "$install_full_tas" \
 "$install_tasw"

addCFLoginToDirEnv "$sys_domain"

if $install_tkgi; then
  remote::configureAndDeployTKGI \
    "$vcenter_host" \
    "$vcenter_password" \
    "$opsman_host" \
    "$tkgi_api_host" \
    "'$om_password'" \
    "$tkgi_version" \
    "$linux_stemcell_name" \
    "$linux_stemcell_version" \
    "$windows_stemcell_version" \
    "$vcenter_datacenter" \
    "$vcenter_datastore" \
    "$vcenter_cluster" \
    "$tkgi_service_cidr" \
    "'$nsxt_t0_gw_name'" \
    "$nsxt_host" \
    "$nsxt_password" \
    "$dns_servers" 

  addTKGILoginToDirEnv "$tkgi_api_host" \
    "$opsman_host" \
    "$om_password"
    
  if $install_genai; then
    remote::createTKGIgenAICluster \
      "$tkgi_api_host" \
      "$tkgi_clustergenai_host" \
      "$tkgi_password"
  fi
fi
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

if $install_tkgi; then
  echo "List TKGI Clusters"
  echo "  tkgi clusters"
  echo 
fi
