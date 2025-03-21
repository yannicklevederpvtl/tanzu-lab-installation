#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=common/local.sh
source ../common/local.sh

# shellcheck source=tpcf_nsx/tas.sh
source ./tas.sh

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
  "'$nsxt_tz_name'" 

 remote::deleteTanzuNetPackages
