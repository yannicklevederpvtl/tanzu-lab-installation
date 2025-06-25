#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=common/local.sh
source ../common/local.sh

# shellcheck source=common/tas.sh
source ../common/tas.sh

# shellcheck source=tpcf_nsx/tasnsx.sh
source ./tasnsx.sh

loadJumpboxConfig
loadConfig "tas.config"

: "${opsman_host:=opsman.${tas_subdomain}.${homelab_domain}}"
: "${tkgi_version:=1.21.0}"
: "${tkgi_nsxt_ingress_cidr:=10.90.0.16/28}"
: "${tkgi_nsxt_egress_cidr:=10.60.0.64/28}"
: "${tkgi_lb_api_virtual_server_ip_address=10.90.0.17}"
: "${tkgi_deployment_nat_gateway_ip=10.60.0.65}"
: "${tkgi_api_host:=tkgi-api.${tas_subdomain}.${homelab_domain}}"

remote::deleteTASAndOpsman \
  "$opsman_host" \
  "'$om_password'" \
  "$opsman_vm_name" \
  "$vcenter_host" \
  "$vcenter_username" \
  "$vcenter_password"

remote::unpaveNSXT \
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

remote::deleteTanzuNetPackages
