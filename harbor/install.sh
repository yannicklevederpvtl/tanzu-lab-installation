#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck source=common/local.sh
source ../common/local.sh

# shellcheck source=common/install.sh
source ../common/install.sh

# shellcheck source=harbor/harbor.sh
source ./harbor.sh

loadJumpboxConfig
loadConfig "harbor.config"


# Prereqs 
: "${homelab_domain?Must provide a homelab_domain env var}"
: "${vcenter_host?Must provide a vcenter_host env var}"
: "${vcenter_username?Must provide a vcenter_username env var}"
: "${vcenter_password?Must provide a vcenter_password env var}"
: "${vcenter_datacenter?Must provide a vcenter_datacenter env var}"
: "${vcenter_cluster?Must provide a vcenter_cluster env var}"
: "${vm_network?Must provide a vm_network env var}"
: "${datastore?Must provide a datastore env var}"

: "${harbor_ip?Must provide a harbor_ip env var}"
: "${harbor_netmask?Must provide a harbor_netmask env var}"
: "${harbor_gateway?Must provide a harbor_gateway env var}"
: "${harbor_password?Must provide a harbor_password env var}"

# Defaults

: "${vcenter_host:=vc01.${homelab_domain}}"
: "${harbor_host:=harbor.${homelab_domain}}"
: "${harbor_dns:=1.1.1.1}"
: "${harbor_vm_name:=harbor}"
: "${harbor_vm_network:=Management}"
: "${harbor_datastore:=vsanDatastore}"
: "${harbor_ram:=4196}"
: "${harbor_disk_size:=100}"


harbor_cidr_bits=$(netmaskToCidrBits "$harbor_netmask")
ssh_public_key=$(cat ../jumpbox/.ssh/id_rsa.pub)

remote::installHarborTools
remote::createHarborVM \
  "'$vcenter_password'" \
  "$vcenter_host" \
  "'$ssh_public_key'" \
  "$harbor_host" \
  "$harbor_vm_name" \
  "$harbor_vm_network" \
  "$harbor_datastore" \
  "$harbor_disk_size" \
  "$harbor_ram" \
  "$harbor_ip" \
  "$harbor_cidr_bits" \
  "$harbor_gateway" \
  "$harbor_dns" \
  "$harbor_password" \
  "$vcenter_datacenter" \
  "$vcenter_cluster" \
  "$esxi_host"

echo "Waiting for Harbor to start, this typically takes ~5min..."
echo
waitForHarborToRespond "$harbor_host"
echo
echo "Harbor is accessible via https://$harbor_host"
echo "Username: admin"
echo "Password: $harbor_password"
echo
echo "To get the CA cert"
echo "scp -O ubuntu@$harbor_ip:/var/cache/harbor/harbor_ca.crt /dev/stdout"
echo "Password: $harbor_password"
echo
