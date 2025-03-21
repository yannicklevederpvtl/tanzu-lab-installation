#!/usr/bin/env bash
set -e
set -u
set -o pipefail

function tanzuNetFileVersion {
  local version="$1"

  # trim -rc.5 etc from the version number if it has one
  version="$(echo "$version" | sed 's/[+*/-].*$//')"
  echo "$version"
}

function findDownloadedCFHubTile {
  local download_dir="$1"
  local product_prefix="$2"
  local version="$3"

  # Get the version number used in the file name
  file_version=$(tanzuNetFileVersion "$version")
  tile_name="${product_prefix}-${file_version}"


  # Find the downloaded tile
  tiles=("${download_dir}"/"${tile_name}"-*.pivotal)

  [[ -e "${tiles[*]}" ]] && tile="${tiles=[0]}"

  if [ -z "${tile}" ]; then
    echo "could not find ${tile} in ${download_dir} folder"
    exit 1
  fi
  
  echo "$tile"
}

function findDownloadedOpsmanTile {
  local download_dir="$1"
  local product_prefix="$2"
  local version="$3"

  # Get the version number used in the file name
  file_version=$(tanzuNetFileVersion "$version")
  tile_name="${product_prefix}-${file_version}"

  # Find the downloaded tile
  tiles=("${download_dir}"/"${tile_name}"-*.pivotal)
  [[ -e "${tiles[*]}" ]] && tile="${tiles=[0]}"

  if [ -z "${tile}" ]; then
    echo "could not find ${tile} in ${download_dir} folder"
    exit 1
  fi
  
  echo "$tile"
}

function findDownloadedGenaiTile {
  local download_dir="$1"
  local product_prefix="$2"
  local version="$3"

  # Get the version number used in the file name
  file_version=$(tanzuNetFileVersion "$version")
  tile_name="${product_prefix}-${file_version}"

  # Find the downloaded tile
  tiles=("${download_dir}"/"${tile_name}"*.pivotal)
  [[ -e "${tiles[*]}" ]] && tile="${tiles=[0]}"

  if [ -z "${tile}" ]; then
    echo "could not find ${tile} in ${download_dir} folder"
    exit 1
  fi
  
  echo "$tile"
}

function remote::deployOpsman {
  remoteExec 'deployOpsman' "$@"
}

function deployOpsman {
  local vcenter_host="$1"
  local vcenter_password="$2"
  local opsman_version="$3"
  local vcenter_pool="$4"
  local opsman_network="$5"
  local vcenter_username="$6"
  local dns_servers="$7"
  local ntp_servers="$8"
  local vcenter_datacenter="$9"
  local vcenter_cluster="${10}"
  local opsman_vm_name="${11:-ops-manager}"
  local opsman_private_ip="${12:-192.168.11.3}"
  local opsman_gateway="${13:-192.168.11.1}"
  local vcenter_datastore="${14}"

  opsman_ovas=("${HOME}"/Downloads/ops-manager-vsphere-"${opsman_version}"*.ova)
  opsman_ova="${opsman_ovas=[0]}"

  # Deploy Opsman VM
  export \
    GOVC_URL="${vcenter_host}" \
    GOVC_INSECURE=1 \
    GOVC_USERNAME="${vcenter_username}" \
    GOVC_PASSWORD="${vcenter_password}"

  returnsSomething() {
    local bytes
    bytes="$( "$@" | wc -c )"

    [[ "$bytes" -ne 0 ]]
  }

  # if returnsSomething govc pool.info "/vc01/host/vc01cl01/Resources/$vcenter_pool" ; then
  if returnsSomething govc pool.info "/$vcenter_datacenter/host/$vcenter_cluster/Resources/$vcenter_pool" ; then
    echo >&2 "Pool $vcenter_pool already exists, skipping creation"
  else
    govc pool.create "/$vcenter_datacenter/host/$vcenter_cluster/Resources/$vcenter_pool"
  fi

  if returnsSomething govc vm.info "$opsman_vm_name" ; then
    echo >&2 "Opsmanager VM already exists, skipping creation"
  else
    # generate the VApp properties file for the opsman OVA
    
    public_ssh_key=$(cat ~/.ssh/id_rsa.pub)
cat << EOF > /tmp/opsman.json
{
    "DiskProvisioning": "flat",
    "IPAllocationPolicy": "dhcpPolicy",
    "IPProtocol": "IPv4",
    "PropertyMapping": [
      {
        "Key": "ip0",
        "Value": "$opsman_private_ip"
      },
      {
        "Key": "netmask0",
        "Value": "255.255.255.0"
      },
      {
        "Key": "gateway",
        "Value": "$opsman_gateway"
      },
      {
        "Key": "DNS",
        "Value": "$dns_servers"
      },
      {
        "Key": "ntp_servers",
        "Value": "$ntp_servers"
      },
      {
        "Key": "public_ssh_key",
        "Value": "$public_ssh_key"
      },
      {
        "Key": "custom_hostname",
        "Value": ""
      }
    ],
    "NetworkMapping": [
      {
        "Name": "Network 1",
        "Network": "$opsman_network"
      }
    ],
    "Annotation": "Tanzu Ops Manager installs and manages products and services.",
    "MarkAsTemplate": false,
    "PowerOn": false,
    "InjectOvfEnv": false,
    "WaitForIP": false,
    "Name": null
}
EOF
    govc import.ova -name "$opsman_vm_name" -pool "$vcenter_pool" -ds "$vcenter_datastore" --options /tmp/opsman.json "${opsman_ova}" 
    govc vm.power -on "$opsman_vm_name"

    rm /tmp/opsman.json
  fi
}

function remote::configureAndDeployBOSH {
  local director_config="${14}"
  scpFile "$director_config" /tmp/director.yml
  remoteExec 'configureAndDeployBOSH' "$@"
}

function configureAndDeployBOSH {
  local vcenter_host="$1"
  local nsxt_host="$2"
  local opsman_host="$3"
  local om_password="$4"
  local vcenter_password="$5"
  local nsxt_password="$6"
  local vcenter_datacenter="$7"
  local vcenter_cluster="$8"
  local vcenter_pool="$9"
  local vcenter_datastore="${10}"
  local dns_servers="${11}"
  local ntp_servers="${12}"
  local vcenter_username="${13}"


  # wait until opsman is responding on port 443
  until nc -vzw5 "$opsman_host" 443; do sleep 5; done
  sleep 60
  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

  # Configure Opsman auth
  om -o 360 configure-authentication \
    --username admin \
    --password "${om_password}" \
    --decryption-passphrase "${om_password}"

  # Configure BOSH director
  openssl s_client -showcerts -connect "${nsxt_host}:443" < /dev/null 2> /dev/null | openssl x509 > /tmp/nsxt_host.pem
  om configure-director \
    --config /tmp/director.yml \
    --var "iaas-configurations_0_nsx_address=${nsxt_host}" \
    --var "iaas-configurations_0_nsx_ca_certificate=$(cat /tmp/nsxt_host.pem)" \
    --var "iaas-configurations_0_nsx_password=${nsxt_password}" \
    --var "iaas-configurations_0_vcenter_host=${vcenter_host}" \
    --var "iaas-configurations_0_vcenter_username=${vcenter_username}" \
    --var "iaas-configurations_0_vcenter_password=${vcenter_password}" \
    --var "iaas-configurations_0_vcenter_datacenter=${vcenter_datacenter}" \
    --var "iaas-configurations_0_vcenter_cluster=${vcenter_cluster}" \
    --var "iaas-configurations_0_vcenter_pool=${vcenter_pool}" \
    --var "iaas-configurations_0_vcenter_datastore=${vcenter_datastore}" \
    --var "iaas-configurations_0_dns_servers=${dns_servers}" \
    --var "iaas-configurations_0_ntp_servers=${ntp_servers}" 
  # Deploy only the BOSH director
  om apply-changes --skip-deploy-products
}

function remote::configureAndDeployBOSHvDS {
  local director_config="${23}"
  scpFile "$director_config" /tmp/director.yml
  remoteExec 'configureAndDeployBOSHvDS' "$@"
}

function configureAndDeployBOSHvDS {
  local vcenter_host="$1"
  local opsman_host="$2"
  local om_password="$3"
  local vcenter_password="$4"
  local vcenter_datacenter="$5"
  local vcenter_cluster="$6"
  local vcenter_pool="$7"
  local vcenter_datastore="$8"
  local infrastructure_network_identifier="$9"
  local infrastructure_nat_gateway_ip="${10}"
  local infrastructure_cidr="${11}"
  local infrastructure_reserved_ip_ranges="${12}"
  local deployment_network_identifier="${13}"
  local deployment_nat_gateway_ip="${14}"
  local deployment_cidr="${15}"
  local deployment_reserved_ip_ranges="${16}"
  local services_network_identifier="${17}"
  local services_nat_gateway_ip="${18}"
  local services_cidr="${19}"
  local services_reserved_ip_ranges="${20}"
  local dns_servers="${21}"
  local ntp_servers="${22}"

  # wait until opsman is responding on port 443
  until nc -vzw5 "$opsman_host" 443; do sleep 5; done
  sleep 60
  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

  # Configure Opsman auth
  om -o 360 configure-authentication \
    --username admin \
    --password "${om_password}" \
    --decryption-passphrase "${om_password}"

  # Configure BOSH director
  #openssl s_client -showcerts -connect "${nsxt_host}:443" < /dev/null 2> /dev/null | openssl x509 > /tmp/nsxt_host.pem
  om configure-director \
    --config /tmp/director.yml \
    --var "iaas-configurations_0_vcenter_host=${vcenter_host}" \
    --var "iaas-configurations_0_vcenter_password=${vcenter_password}" \
    --var "iaas-configurations_0_vcenter_datacenter=${vcenter_datacenter}" \
    --var "iaas-configurations_0_vcenter_cluster=${vcenter_cluster}" \
    --var "iaas-configurations_0_vcenter_pool=${vcenter_pool}" \
    --var "iaas-configurations_0_vcenter_datastore=${vcenter_datastore}" \
    --var "iaas-configurations_0_infrastructure_network_identifier=${infrastructure_network_identifier}" \
    --var "iaas-configurations_0_infrastructure_nat_gateway_ip=${infrastructure_nat_gateway_ip}" \
    --var "iaas-configurations_0_infrastructure_cidr=${infrastructure_cidr}" \
    --var "iaas-configurations_0_infrastructure_reserved_ip_ranges=${infrastructure_reserved_ip_ranges}" \
    --var "iaas-configurations_0_deployment_network_identifier=${deployment_network_identifier}" \
    --var "iaas-configurations_0_deployment_nat_gateway_ip=${deployment_nat_gateway_ip}" \
    --var "iaas-configurations_0_deployment_cidr=${deployment_cidr}" \
    --var "iaas-configurations_0_deployment_reserved_ip_ranges=${deployment_reserved_ip_ranges}" \
    --var "iaas-configurations_0_services_network_identifier=${services_network_identifier}" \
    --var "iaas-configurations_0_services_nat_gateway_ip=${services_nat_gateway_ip}" \
    --var "iaas-configurations_0_services_cidr=${services_cidr}" \
    --var "iaas-configurations_0_services_reserved_ip_ranges=${services_reserved_ip_ranges}" \
    --var "iaas-configurations_0_dns_servers=${dns_servers}" \
    --var "iaas-configurations_0_ntp_servers=${ntp_servers}" 

  # Deploy only the BOSH director
  om apply-changes --skip-deploy-products
}

function createOpsmanDirEnv {
  cat << EOF > .envrc
#!/usr/bin/env bash

export OM_USERNAME='admin'
export OM_PASSWORD='${om_password}'
export OM_DECRYPTION_PASSPHRASE='${om_password}'
export OM_SKIP_SSL_VALIDATION='true'
export OM_TARGET="${opsman_host}"
export OM_CONNECT_TIMEOUT='30'

# Set the BOSH env vars from opsman
eval "\$(om bosh-env -i "../jumpbox/.ssh/id_rsa")"

export GOVC_URL="${vcenter_host}"
export GOVC_USERNAME='${vcenter_username}'
export GOVC_PASSWORD='${vcenter_password}'
export GOVC_INSECURE=true
EOF
}
