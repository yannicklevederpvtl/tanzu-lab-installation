#!/usr/bin/env bash

set -e
set -u
set -o pipefail


function remote::downloadAviPackages {
    scpFile ./controller-22.1.7-9093.ova /tmp/controller-22.1.7-9093.ova
}


function downloadInstallTKGICLI {
  local tanzu_net_api_token="$1"
  local opsman_version="$2"
  local tkgi_version="$3"
  local linux_stemcell_name="$4"
  local linux_stemcell_version="$5"
  local windows_stemcell_version="$6"

  om download-product -p pivotal-container-service \
    -t "${tanzu_net_api_token}" \
    -f "tkgi-linux-amd64-1.22.0-build.12" \
    --product-version "1.22.1" \
    -o ./
  sudo mv -f ./tkgi-linux-amd64-1.22.0-build.12 /usr/local/bin/tkgi
  chmod +x /usr/local/bin/tkgi

}

function remote::createTKGIgenAICluster {
  scpFile ./default-network-profile.json /tmp/default-network-profile.json
  remoteExec 'createTKGIgenAICluster' "$@"
}

function createTKGIgenAICluster {
  local tkgi_api_host="$1"
  local tkgi_clustergenai_host="$2"
  local tkgi_password="$3"

  local network_profile_file="default-network-profile.json"
  local cluster_name="tkgiclustergenai1"

  tkgi login -a "https://${tkgi_api_host}" -k -u admin -p "${tkgi_password}"

  tkgi create-network-profile "/tmp/${network_profile_file}"

  network_profile_name=$(jq -r '.name' "/tmp/${network_profile_file}")

  tkgi create-cluster "${cluster_name}" \
    --external-hostname "${tkgi_clustergenai_host}" \
    --network-profile "${network_profile_name}" \
    --plan "small"

  echo "Waiting for cluster '$cluster_name' with external-hostname '$tkgi_clustergenai_host' to be created"
  local success=false
  until ${success}; do
    set +e
    local status
    status=$(tkgi cluster "$cluster_name" --json | jq -r '.last_action_state')
    if [ "$status" = "succeeded" ]; then
      success=true
    fi
    if [ "$status" = "failed" ]; then
      echo "Failed to create $cluster_name"
      exit 1
    fi
    set -e
    tkgi cluster "$cluster_name" --json | jq -r '.last_action_description'
    sleep 10
  done
  
  echo "Created $cluster_name successfully"
  echo
  echo "Make sure to create this DNS record before installing the GenAI services"
  echo
  echo "${tkgi_clustergenai_host}. A $(tkgi cluster "$cluster_name" --json | jq -r '.kubernetes_master_ips[0]')"
  echo


}

function remote::configureAndDeployTKGI {
  scpFile ./tkgi.yml /tmp/tkgi.yml
  remoteExec 'configureAndDeployTKGI' "$@"
}

function configureAndDeployTKGI {
  local vcenter_host="$1"
  local vcenter_password="$2"
  local opsman_host="$3"
  local tkgi_api_host="$4"
  local om_password="$5"
  local tkgi_version="$6"
  local linux_stemcell_name="$7"
  local linux_stemcell_version="$8"
  local windows_stemcell_version="$9"
  local vcenter_datacenter="${10}"
  local vcenter_datastore="${11}"
  local vcenter_cluster="${12}"
  local tkgi_service_cidr="${13}"
  local nsxt_t0_gw_name="${14}"
  local nsxt_host="${15}"
  local nsxt_password="${16}"
  local dns_servers="${17}"


  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

  staging_dir="${HOME}/tkgi"
  mkdir -p "${staging_dir}"

  nsxt_cert="${staging_dir}/nsxt_host.cert"
  tkgi_api_cert="${staging_dir}/tkgi_api.cert"
  tkgi_api_key="${staging_dir}/tkgi_api.key"
  superuser_cert="${staging_dir}/nsxt_superuser.cert"
  superuser_key="${staging_dir}/nsxt_superuser.key"

  # Generate and register NSX-T super user with cert
  if [ ! -f "${superuser_cert}" ]; then
    om generate-certificate \
      --domains "*.${tkgi_api_host}" \
      | tee >(jq -r .certificate > "${superuser_cert}") >(jq -r .key > "${superuser_key}")

    cert_request=$(cat <<END
{
  "name": "tkgi-nsx-t-superuser",
  "node_id": "tgki",
  "role": "enterprise_admin",
  "is_protected": "true",
  "certificate_pem" : "$(awk '{printf "%s\\n", $0}' "${superuser_cert}")"
}
END
    )

    curl -k -X POST \
      "https://${nsxt_host}/api/v1/trust-management/principal-identities/with-certificate" \
      -u "admin:${nsxt_password}" \
      -H 'content-type: application/json' \
      -d "$cert_request"
  fi

  # Generate TKGI API cert
  if [ ! -f "${tkgi_api_cert}" ]; then
    om \
      generate-certificate \
      --domains "${tkgi_api_host}" \
      | tee >(jq -r .certificate > "${tkgi_api_cert}") >(jq -r .key > "${tkgi_api_key}")
  fi

  # upload TKGI tile
  tkgi_tiles=("${HOME}/Downloads/pivotal-container-service-${tkgi_version}"-build.*.pivotal)
  tkgi_tile="${tkgi_tiles=[0]}"

  om upload-product -p "$tkgi_tile"
  build_ver=$(om products -a -f json | jq -r '.[] | select(.name == "pivotal-container-service") | .available | .[]')
  om stage-product --product-name=pivotal-container-service --product-version="${build_ver}"

  # upload missing stemcell
  ubuntu_stemcells=("${HOME}"/Downloads/bosh-stemcell-"${linux_stemcell_version}"-vsphere-esxi-ubuntu-"${linux_stemcell_name}"-go_agent.tgz)
  ubuntu_stemcell="${ubuntu_stemcells=[0]}"
  om upload-stemcell -s "${ubuntu_stemcell}" --floating=false


  # Grab the NSX-T manager TLS cert
  set +e
  openssl s_client -showcerts -connect "${nsxt_host}:443" < /dev/null 2> /dev/null | openssl x509 > "${nsxt_cert}"
  set -e

  # Configure TKGI
  om configure-product \
    --config /tmp/tkgi.yml \
    --var "tkgi_api_host=${tkgi_api_host}" \
    --var "vcenter_host=${vcenter_host}" \
    --var "vcenter_username=administrator@vsphere.local" \
    --var "vcenter_password=${vcenter_password}" \
    --var "vcenter_datacenter=${vcenter_datacenter}" \
    --var "vcenter_datastore=${vcenter_datastore}" \
    --var "vcenter_cluster=${vcenter_cluster}" \
    --var "pivotal-container-service_pks_tls.cert_pem=$(cat "${tkgi_api_cert}")" \
    --var "pivotal-container-service_pks_tls.private_key_pem=$(cat "${tkgi_api_key}")" \
    --var "tkgi_service_cidr=${tkgi_service_cidr}" \
    --var "iaas-configurations_0_nsx_address=${nsxt_host}" \
    --var "floating_ip_pool_id=tkgi-ingress-floating-pool" \
    --var "nodes_ip_block_id=tkgi-nodes-block" \
    --var "pods_ip_block_id=tkgi-pods-block" \
    --var "iaas-configurations_0_nsx_ca_certificate=$(cat "${nsxt_cert}")" \
    --var "pivotal-container-service_pks_tls.cert_pem=$(cat "${tkgi_api_cert}")" \
    --var "pivotal-container-service_pks_tls.private_key_pem=$(cat "${tkgi_api_key}")" \
    --var "properties_network_selector_nsx_nsx-t-superuser-certificate.cert_pem=$(cat "${superuser_cert}")" \
    --var "properties_network_selector_nsx_nsx-t-superuser-certificate.private_key_pem=$(cat "${superuser_key}")" \
    --var "t0_router_id='${nsxt_t0_gw_name}'" \
    --var "dns_servers=${dns_servers}"

 om apply-changes --product-name "pivotal-container-service"
}

function addTKGILoginToDirEnv {
  local tkgi_api_host="$1"
  local opsman_host="$2"
  local om_password="$3"

  OM_USERNAME='admin'
  OM_PASSWORD="${om_password}"
  OM_DECRYPTION_PASSPHRASE="${om_password}"
  OM_SKIP_SSL_VALIDATION='true'
  OM_TARGET="${opsman_host}"
  OM_CONNECT_TIMEOUT='30'

  export tkgi_password=$(om credentials -p pivotal-container-service -c '.properties.uaa_admin_password' -t json | jq -r .secret)

  if ! grep -q 'tkgi login' .envrc 2> /dev/null; then
    cat >> .envrc <<EOF

# Login to TKGI API as admin
tkgi login -a "https://${tkgi_api_host}" -k -u admin -p "\$(om credentials -p pivotal-container-service -c '.properties.uaa_admin_password' -t json | jq -r .secret)"
EOF
fi
}
