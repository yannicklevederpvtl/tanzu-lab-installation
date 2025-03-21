#!/usr/bin/env bash
set -e
set -u
set -o pipefail

function remote::installHarborTools {
  remoteExec 'installHarborTools'
}

function installHarborTools {
  installTerraform
}

function remote::createHarborVM {
  scpDir ./terraform-harbor /home/ubuntu
  remoteExec 'createHarborVM' "$@"
}

function createHarborVM() {
  local vcenter_password="$1"
  local vcenter_host="$2"
  local ssh_public_key="$3"
  local harbor_host="$4"
  local harbor_vm_name="$5"
  local harbor_vm_network="$6"
  local harbor_datastore="$7"
  local harbor_disk_size="$8"
  local harbor_ram="$9"
  local harbor_ip="${10}"
  local harbor_cidr_bits="${11}"
  local harbor_gateway="${12}"
  local harbor_dns="${13}"
  local harbor_password="${14}"
  local vcenter_datacenter="${15}"
  local vcenter_cluster="${16}"
  local esxi_host="${17}"

  pushd terraform-harbor || exit

  # turn comma delimited string into comma delimited array of strings
  nslist=()
  for ns in $(echo "$harbor_dns" | tr ',' "\n"); do
    nslist+=( "\"${ns}\"" )
  done
  nameservers=$(printf ",%s" "${nslist[@]}")
  nameservers="[${nameservers:1}]"

  terraform init -reconfigure
  terraform apply -auto-approve \
    -var='allow_unverified_ssl=true' \
    -var="vsphere_server=${vcenter_host}" \
    -var="vsphere_datacenter=${vcenter_datacenter}" \
    -var="vsphere_cluster=${vcenter_cluster}" \
    -var="esxi_host=${esxi_host}" \
    -var="vsphere_user=administrator@vsphere.local" \
    -var="vsphere_password=${vcenter_password}" \
    \
    -var="harbor_host=${harbor_host}" \
    -var="ip_address=${harbor_ip}" \
    -var="network_cidr_bits=${harbor_cidr_bits}" \
    -var="gateway=${harbor_gateway}" \
    -var="nameservers=${nameservers}" \
    \
    -var="vm_name=${harbor_vm_name}" \
    -var="vsphere_network=${harbor_vm_network}" \
    -var="vsphere_datastore=${harbor_datastore}" \
    -var="disk_size=${harbor_disk_size}" \
    -var="ram=${harbor_ram}" \
    \
    -var="password=${harbor_password}" \
    -var="ssh_public_key=${ssh_public_key}" \

    popd
}

function remote::destroyHarborVM {
  remoteExec 'destroyHarborVM' "$@"
}

function destroyHarborVM() {

  rm -rf "/home/ubuntu/terraform-harbor/"

}

function waitForHarborToRespond() {
  local harbor_host="$1"

  # wait until jumpbox is responding on port 443
  until nc -vzw5 "$harbor_host" 443; do sleep 15; done
}
