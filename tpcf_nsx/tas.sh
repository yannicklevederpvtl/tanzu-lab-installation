#!/usr/bin/env bash
set -e
set -u
set -o pipefail

function remote::installTASTools {
  remoteExec 'installTASTools'
}

function installTASTools {
  installOm
  installGovc
  installJq
  installTerraform
}

function remote::deleteTanzuNetPackages {
  remoteExec 'deleteTanzuNetPackages'
}

function deleteTanzuNetPackages {
  rm -rf "/home/ubuntu/Downloads/"
}

# function remote::downloadTPSMPackages {
#   remoteExec 'downloadTanzuNetPackages' "$@"
# }

# function downloadTPSMPackages {
#   local tanzu_net_api_token="$1"
#   local install_tpsm="$2"
#   local tpsm_version="$3"

#   if $install_tpsm; then

#     om download-product -p tanzu-platform \
#       -t "${tanzu_net_api_token}" \
#       -f "tanzu-self-managed-*.tar.gz.part_aa" \
#       --product-version "${tpsm_version}" \
#       -o ~/Downloads
#     om download-product -p tanzu-platform \
#       -t "${tanzu_net_api_token}" \
#       -f "tanzu-self-managed-*.tar.gz.part_ab" \
#       --product-version "${tpsm_version}" \
#       -o ~/Downloads
#     om download-product -p tanzu-platform \
#       -t "${tanzu_net_api_token}" \
#       -f "tanzu-self-managed-*.tar.gz.part_ac" \
#       --product-version "${tpsm_version}" \
#       -o ~/Downloads
#     om download-product -p tanzu-platform \
#       -t "${tanzu_net_api_token}" \
#       -f "tanzu-self-managed-*.tar.gz.part_ad" \
#       --product-version "${tpsm_version}" \
#       -o ~/Downloads
#   fi

# }

function remote::downloadTanzuNetPackages {
  remoteExec 'downloadTanzuNetPackages' "$@"
}



function downloadTanzuNetPackages {
  local tanzu_net_api_token="$1"
  local opsman_version="$2"
  local tas_version="$3"
  local linux_stemcell_name="$4"
  local linux_stemcell_version="$5"
  local windows_stemcell_version="$6"
  local install_full_tas="$7"
  local install_tasw="$8"
  local install_tkgi="$9"
  local tkgi_version="${10}"


  tile_glob='srt-*.pivotal'
  if [ "$install_full_tas" = true ]; then
    tile_glob='cf-*.pivotal'
  fi

  mkdir -p ~/Downloads

  # Download Opsman and TAS from Pivnet
  om download-product -p ops-manager \
    -t "${tanzu_net_api_token}" \
    -f 'ops-manager-vsphere-*.ova' \
    --product-version "${opsman_version}" \
    -o ~/Downloads
  
  #  om download-product -p cf \
  #   -t "${tanzu_net_api_token}" \
  #   -f "${tile_glob}" \
  #   --product-version "${tas_version}" \
  #   -o ~/Downloads

  om download-product -p elastic-runtime \
   -t "${tanzu_net_api_token}" \
    -f "${tile_glob}" \
   --product-version "${tas_version}" \
   -o ~/Downloads

  om download-product -p "stemcells-ubuntu-${linux_stemcell_name}" \
    -t "${tanzu_net_api_token}" \
   -f "bosh-stemcell-*-vsphere-esxi-ubuntu-${linux_stemcell_name}-go_agent.tgz" \
    --product-version "${linux_stemcell_version}" \
    -o ~/Downloads

  if $install_tkgi; then

    om download-product -p pivotal-container-service \
      -t "${tanzu_net_api_token}" \
      -f "pivotal-container-service-*.pivotal" \
      --product-version "${tkgi_version}" \
      -o ~/Downloads

    if [ ! -f /usr/local/bin/pks ]; then
      om download-product -p pivotal-container-service \
      -t "${tanzu_net_api_token}" \
      -f "pks-linux-amd64-1.22.0-build.12" \
      --product-version "${tkgi_version}" \
      -o ~/Downloads

      sudo mv ~/Downloads/pks-linux-amd64-1.22.0-build.12 /usr/local/bin/pks
      sudo chmod +x /usr/local/bin/pks
    fi

    if [ ! -f /usr/local/bin/tkgi ]; then
      om download-product -p pivotal-container-service \
      -t "${tanzu_net_api_token}" \
      -f "tkgi-linux-amd64-1.22.0-build.12" \
      --product-version "${tkgi_version}" \
      -o ~/Downloads

      sudo mv ~/Downloads/tkgi-linux-amd64-1.22.0-build.12 /usr/local/bin/tkgi
      sudo chmod +x /usr/local/bin/tkgi
    fi

    if [ ! -f /usr/local/bin/kubectl ]; then
      om download-product -p pivotal-container-service \
      -t "${tanzu_net_api_token}" \
      -f "kubectl-linux-amd64-1.31.5" \
      --product-version "${tkgi_version}" \
      -o ~/Downloads

      sudo mv ~/Downloads/kubectl-linux-amd64-1.31.5 /usr/local/bin/kubectl
      sudo chmod +x /usr/local/bin/kubectl
    fi


  fi
  if $install_tasw; then
    tile_glob='pas-windows-*.pivotal'

    # Download and TASW, injector and stemcell from Pivnet
    om download-product -p pas-windows \
      -t "${tanzu_net_api_token}" \
      -f "${tile_glob}" \
      --product-version "${tas_version}" \
      -o ~/Downloads

    om download-product -p pas-windows \
      -t "${tanzu_net_api_token}" \
      -f "winfs-injector-*.zip" \
      --product-version "${tas_version}" \
      -o ~/Downloads

    om download-product -p stemcells-windows-server-internal \
      -t "${tanzu_net_api_token}" \
      -f "bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz" \
      --product-version "${windows_stemcell_version}" \
      -o ~/Downloads
  fi
}

function remote::downloadTanzuNetServicesPackages {
  remoteExec 'downloadTanzuNetServicesPackages' "$@"
}

function downloadTanzuNetServicesPackages {
  local tanzu_net_api_token="$1"
  local opsman_version="$2"
  local tas_version="$3"
  local install_genai="$4"
  local genai_version="$5"
  local install_postgres="$6"
  local postgres_version="$7"

  if $install_genai; then
    tile_glob='genai-*.pivotal'
    om download-product -p genai-for-tas \
    -t "${tanzu_net_api_token}" \
    -f "${tile_glob}" \
    --product-version "${genai_version}" \
    -o ~/Downloads
  fi
  if $install_postgres; then
    tile_glob='postgres-*.pivotal'
    tile_version=$(tanzuNetFileVersion "$postgres_version")
    om download-product -p vmware-postgres-for-tas \
    -t "${tanzu_net_api_token}" \
    -f "${tile_glob}" \
    --product-version "${tile_version}" \
    -o ~/Downloads
  fi
}

function remote::downloadTanzuNetHealthwatchPackages {
  remoteExec 'downloadTanzuNetHealthwatchPackages' "$@"
}

function downloadTanzuNetHealthwatchPackages {
  local tanzu_net_api_token="$1"
  local opsman_version="$2"
  local tas_version="$3"
  local heatlthwatch_version="$4"
  local install_tkgi="$5"
  local install_genai="$6"

  tile_glob="healthwatch-${heatlthwatch_version}*.pivotal"
  om download-product -p p-healthwatch \
  -t "${tanzu_net_api_token}" \
  -f "${tile_glob}" \
  --product-version "${heatlthwatch_version}" \
  -o ~/Downloads

  tile_glob="healthwatch-pas*.pivotal"
  om download-product -p p-healthwatch \
  -t "${tanzu_net_api_token}" \
  -f "${tile_glob}" \
  --product-version "${heatlthwatch_version}" \
  -o ~/Downloads

  if $install_tkgi; then
    tile_glob="healthwatch-pks*.pivotal"
    om download-product -p p-healthwatch \
    -t "${tanzu_net_api_token}" \
    -f "${tile_glob}" \
    --product-version "${heatlthwatch_version}" \
    -o ~/Downloads
  fi

}


function remote::unpaveNSXT {
  remoteExec 'unpaveNSXT' "$@"
}

function unpaveNSXT {
  local nsxt_host="$1"
  local nsxt_password="$2"
  local tas_ops_manager_public_ip="$3"
  local tas_lb_web_virtual_server_ip_address="$4"
  local tas_lb_tcp_virtual_server_ip_address="$5"
  local tas_lb_ssh_virtual_server_ip_address="$6"
  local tas_infrastructure_nat_gateway_ip="$7"
  local tas_deployment_nat_gateway_ip="$8"
  local tas_services_nat_gateway_ip="$9"
  local nsxt_username="${10}"
  local nsxt_edgecluster_name="${11}"
  local nsxt_t0_gw_name="${12}"
  local nsxt_tz_name="${13}"
  local install_tkgi=${14}
  local tkgi_nsxt_ingress_cidr=${15}
  local tkgi_nsxt_egress_cidr=${16}
  local tkgi_lb_api_virtual_server_ip_address=${17}
  local tkgi_deployment_nat_gateway_ip=${18}

  if $install_tkgi; then

      pushd terraform-tas-tkgi-nsxt || exit
    
      terraform destroy -auto-approve \
        -var='allow_unverified_ssl=true' \
        -var="nsxt_edge_cluster_name=${nsxt_edgecluster_name}" \
        -var="east_west_transport_zone_name=${nsxt_tz_name}" \
        -var="nsxt_active_t0_gateway_name=${nsxt_t0_gw_name}" \
        -var='tas_ops_manager_private_ip=192.168.11.3' \
        -var='tas_infra_cidr=192.168.11.0/24' \
        -var='tas_deployment_cidr=192.168.12.0/24' \
        -var='tas_services_cidr=192.168.13.0/24' \
        -var='tas_lb_tcp_virtual_server_ports=["18000-32767"]' \
        -var='tas_container_ip_block_cidr=172.16.0.0/14' \
        -var='tas_ncp_external_snat_ip_pool_cidr=10.10.10.0/24' \
        -var='tas_orgs_external_snat_ip_pool_start=10.10.10.10' \
        -var='tas_orgs_external_snat_ip_pool_stop=10.10.10.250' \
        -var='use_ncp_container_networking=false' \
        \
        -var="tas_ops_manager_public_ip=${tas_ops_manager_public_ip}" \
        -var="tas_lb_web_virtual_server_ip_address=${tas_lb_web_virtual_server_ip_address}" \
        -var="tas_lb_tcp_virtual_server_ip_address=${tas_lb_tcp_virtual_server_ip_address}" \
        -var="tas_lb_ssh_virtual_server_ip_address=${tas_lb_ssh_virtual_server_ip_address}" \
        \
        -var="tas_infrastructure_nat_gateway_ip=${tas_infrastructure_nat_gateway_ip}" \
        -var="tas_deployment_nat_gateway_ip=${tas_deployment_nat_gateway_ip}" \
        -var="tas_services_nat_gateway_ip=${tas_services_nat_gateway_ip}" \
        \
        -var='tkgi_deployment_cidr=192.168.14.0/24' \
        -var="tkgi_nsxt_ingress_cidr=${tkgi_nsxt_ingress_cidr}" \
        -var="tkgi_nsxt_egress_cidr=${tkgi_nsxt_egress_cidr}" \
        -var="tkgi_lb_api_virtual_server_ip_address=${tkgi_lb_api_virtual_server_ip_address}" \
        -var="tkgi_deployment_nat_gateway_ip=${tkgi_deployment_nat_gateway_ip}" \
        \
        -var="nsxt_host=${nsxt_host}" \
        -var="nsxt_username=${nsxt_username}" \
        -var="nsxt_password=${nsxt_password}"
      
      curl -k -X PATCH -H 'Content-Type: application/json' -d @./profiles_and_monitors_delete.json \
        -u "admin:${nsxt_password}" \
        "https://${nsxt_host}/policy/api/v1/infra/"

      popd

  else

      pushd terraform-tas-nsxt || exit
    
      terraform destroy -auto-approve \
        -var='allow_unverified_ssl=true' \
        -var="nsxt_edge_cluster_name=${nsxt_edgecluster_name}" \
        -var="east_west_transport_zone_name=${nsxt_tz_name}" \
        -var="nsxt_active_t0_gateway_name=${nsxt_t0_gw_name}" \
        -var='tas_ops_manager_private_ip=192.168.11.3' \
        -var='tas_infra_cidr=192.168.11.0/24' \
        -var='tas_deployment_cidr=192.168.12.0/24' \
        -var='tas_services_cidr=192.168.13.0/24' \
        -var='tas_lb_tcp_virtual_server_ports=["18000-32767"]' \
        -var='tas_container_ip_block_cidr=172.16.0.0/14' \
        -var='tas_ncp_external_snat_ip_pool_cidr=10.10.10.0/24' \
        -var='tas_orgs_external_snat_ip_pool_start=10.10.10.10' \
        -var='tas_orgs_external_snat_ip_pool_stop=10.10.10.250' \
        -var='use_ncp_container_networking=false' \
        \
        -var="tas_ops_manager_public_ip=${tas_ops_manager_public_ip}" \
        -var="tas_lb_web_virtual_server_ip_address=${tas_lb_web_virtual_server_ip_address}" \
        -var="tas_lb_tcp_virtual_server_ip_address=${tas_lb_tcp_virtual_server_ip_address}" \
        -var="tas_lb_ssh_virtual_server_ip_address=${tas_lb_ssh_virtual_server_ip_address}" \
        \
        -var="tas_infrastructure_nat_gateway_ip=${tas_infrastructure_nat_gateway_ip}" \
        -var="tas_deployment_nat_gateway_ip=${tas_deployment_nat_gateway_ip}" \
        -var="tas_services_nat_gateway_ip=${tas_services_nat_gateway_ip}" \
        \
        -var="nsxt_host=${nsxt_host}" \
        -var="nsxt_username=${nsxt_username}" \
        -var="nsxt_password=${nsxt_password}"
      
      curl -k -X PATCH -H 'Content-Type: application/json' -d @./profiles_and_monitors_delete.json \
        -u "admin:${nsxt_password}" \
        "https://${nsxt_host}/policy/api/v1/infra/"

      popd

  fi

  # rm -rf "/home/ubuntu/terraform-tas-nsxt/"
  # rm -rf "/home/ubuntu/terraform-tas-tkgi-nsxt/"
}

function remote::paveNSXT {
  scpDir ./terraform-tas-nsxt /home/ubuntu
  scpDir ./terraform-tas-tkgi-nsxt /home/ubuntu
  remoteExec 'paveNSXT' "$@"
}

function paveNSXT {
  local nsxt_host="$1"
  local nsxt_password="$2"
  local tas_ops_manager_public_ip="$3"
  local tas_lb_web_virtual_server_ip_address="$4"
  local tas_lb_tcp_virtual_server_ip_address="$5"
  local tas_lb_ssh_virtual_server_ip_address="$6"
  local tas_infrastructure_nat_gateway_ip="$7"
  local tas_deployment_nat_gateway_ip="$8"
  local tas_services_nat_gateway_ip="$9"
  local nsxt_username="${10}"
  local nsxt_edgecluster_name="${11}"
  local nsxt_t0_gw_name="${12}"
  local nsxt_tz_name="${13}"
  local install_tkgi=${14}
  local tkgi_nsxt_ingress_cidr=${15}
  local tkgi_nsxt_egress_cidr=${16}
  local tkgi_lb_api_virtual_server_ip_address=${17}
  local tkgi_deployment_nat_gateway_ip=${18}


  if $install_tkgi; then
    
    pushd terraform-tas-tkgi-nsxt || exit
    # deploy some profiles and monitors we can't handle with tf
    curl -k -X PATCH -H 'Content-Type: application/json' -d @./profiles_and_monitors.json \
    -u "admin:${nsxt_password}" \
    "https://${nsxt_host}/policy/api/v1/infra/"

    terraform init -reconfigure

    terraform apply -auto-approve \
      -var='allow_unverified_ssl=true' \
      -var="nsxt_edge_cluster_name=${nsxt_edgecluster_name}" \
      -var="east_west_transport_zone_name=${nsxt_tz_name}" \
      -var="nsxt_active_t0_gateway_name=${nsxt_t0_gw_name}" \
      -var='tas_ops_manager_private_ip=192.168.11.3' \
      -var='tas_infra_cidr=192.168.11.0/24' \
      -var='tas_deployment_cidr=192.168.12.0/24' \
      -var='tas_services_cidr=192.168.13.0/24' \
      -var='tas_lb_tcp_virtual_server_ports=["18000-32767"]' \
      -var='tas_container_ip_block_cidr=172.16.0.0/14' \
      -var='tas_ncp_external_snat_ip_pool_cidr=10.10.10.0/24' \
      -var='tas_orgs_external_snat_ip_pool_start=10.10.10.10' \
      -var='tas_orgs_external_snat_ip_pool_stop=10.10.10.250' \
      -var='use_ncp_container_networking=false' \
      \
      -var="tas_ops_manager_public_ip=${tas_ops_manager_public_ip}" \
      -var="tas_lb_web_virtual_server_ip_address=${tas_lb_web_virtual_server_ip_address}" \
      -var="tas_lb_tcp_virtual_server_ip_address=${tas_lb_tcp_virtual_server_ip_address}" \
      -var="tas_lb_ssh_virtual_server_ip_address=${tas_lb_ssh_virtual_server_ip_address}" \
      \
      -var="tas_infrastructure_nat_gateway_ip=${tas_infrastructure_nat_gateway_ip}" \
      -var="tas_deployment_nat_gateway_ip=${tas_deployment_nat_gateway_ip}" \
      -var="tas_services_nat_gateway_ip=${tas_services_nat_gateway_ip}" \
      \
      -var='tkgi_deployment_cidr=192.168.14.0/24' \
      -var="tkgi_nsxt_ingress_cidr=${tkgi_nsxt_ingress_cidr}" \
      -var="tkgi_nsxt_egress_cidr=${tkgi_nsxt_egress_cidr}" \
      -var="tkgi_lb_api_virtual_server_ip_address=${tkgi_lb_api_virtual_server_ip_address}" \
      -var="tkgi_deployment_nat_gateway_ip=${tkgi_deployment_nat_gateway_ip}" \
      \
      -var="nsxt_host=${nsxt_host}" \
      -var="nsxt_username=${nsxt_username}" \
      -var="nsxt_password=${nsxt_password}"

    popd

  else
    
    pushd terraform-tas-nsxt || exit
    # deploy some profiles and monitors we can't handle with tf
    curl -k -X PATCH -H 'Content-Type: application/json' -d @./profiles_and_monitors.json \
    -u "admin:${nsxt_password}" \
    "https://${nsxt_host}/policy/api/v1/infra/"

    terraform init -reconfigure

    terraform apply -auto-approve \
      -var='allow_unverified_ssl=true' \
      -var="nsxt_edge_cluster_name=${nsxt_edgecluster_name}" \
      -var="east_west_transport_zone_name=${nsxt_tz_name}" \
      -var="nsxt_active_t0_gateway_name=${nsxt_t0_gw_name}" \
      -var='tas_ops_manager_private_ip=192.168.11.3' \
      -var='tas_infra_cidr=192.168.11.0/24' \
      -var='tas_deployment_cidr=192.168.12.0/24' \
      -var='tas_services_cidr=192.168.13.0/24' \
      -var='tas_lb_tcp_virtual_server_ports=["18000-32767"]' \
      -var='tas_container_ip_block_cidr=172.16.0.0/14' \
      -var='tas_ncp_external_snat_ip_pool_cidr=10.10.10.0/24' \
      -var='tas_orgs_external_snat_ip_pool_start=10.10.10.10' \
      -var='tas_orgs_external_snat_ip_pool_stop=10.10.10.250' \
      -var='use_ncp_container_networking=false' \
      \
      -var="tas_ops_manager_public_ip=${tas_ops_manager_public_ip}" \
      -var="tas_lb_web_virtual_server_ip_address=${tas_lb_web_virtual_server_ip_address}" \
      -var="tas_lb_tcp_virtual_server_ip_address=${tas_lb_tcp_virtual_server_ip_address}" \
      -var="tas_lb_ssh_virtual_server_ip_address=${tas_lb_ssh_virtual_server_ip_address}" \
      \
      -var="tas_infrastructure_nat_gateway_ip=${tas_infrastructure_nat_gateway_ip}" \
      -var="tas_deployment_nat_gateway_ip=${tas_deployment_nat_gateway_ip}" \
      -var="tas_services_nat_gateway_ip=${tas_services_nat_gateway_ip}" \
      \
      -var="nsxt_host=${nsxt_host}" \
      -var="nsxt_username=${nsxt_username}" \
      -var="nsxt_password=${nsxt_password}"

    popd
    
  fi



}

function remote::deleteTASAndOpsman {

  remoteExec 'deleteTASAndOpsman' "$@"
}

function deleteTASAndOpsman {
  local opsman_host="$1"
  local om_password="$2"
  local opsman_vm_name="$3"
  local vcenter_host="$4"
  local vcenter_username="$5"
  local vcenter_password="$6"

  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

    om delete-installation

    : "${vcenter_password?Must provide a vcenter_password env var}"

    # Defaults  
    : "${vcenter_host:=vcenter.${homelab_domain}}"
    : "${vm_name:=jumpbox}"
    : "${vcenter_username:=administrator@vsphere.local}"

    # Setup govc creds n' stuff
    export \
    GOVC_INSECURE=1 \
    GOVC_USERNAME="${vcenter_username}" \
    GOVC_PASSWORD="${vcenter_password}" \
    GOVC_URL="${vcenter_host}"

    # delete VM and disks
    govc vm.destroy \
    "${opsman_vm_name}"

}

function remote::configureAndDeployTAS {
  local tas_version="$5"
  local install_full_tas="$8"

  config_file=$(findTASProductConfigFile "${HELPER_DIR}/tpcf_nsx/cf" "$tas_version" "$install_full_tas")
  scpFile "$config_file" /tmp/tas.yml
  if $install_tasw; then
    scpFile ./tasw.yml /tmp/tasw.yml
  fi
  remoteExec 'configureAndDeployTAS' "$@"
}

function configureAndDeployTAS {
  local opsman_host="$1"
  local om_password="$2"
  local sys_domain="$3"
  local apps_domain="$4"
  local tas_version="$5"
  local linux_stemcell_name="$6"
  local linux_stemcell_version="$7"
  local install_full_tas="$8"
  local install_tasw="$9"

  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

  # Generate POE and UAA SAML cert
  om generate-certificate \
    --domains "*.${sys_domain},*.${apps_domain},*.login.${sys_domain},*.uaa.${sys_domain}" \
    | tee >(jq -r .certificate > /tmp/wildcard.pem) >(jq -r .key > /tmp/wildcard.key)

  tile_version=$(tanzuNetFileVersion "$tas_version")

  tile_prefix=$(if $install_full_tas; then echo 'cf'; else echo 'srt'; fi)

  tas_tile=$(findDownloadedOpsmanTile "${HOME}/Downloads" "$tile_prefix" "$tile_version")

# upload and stage the tile
  om -r=10800 --trace upload-product -p "$tas_tile"  
  om stage-product --product-name=cf --product-version="${tile_version}"
  
  ubuntu_stemcells=("${HOME}"/Downloads/bosh-stemcell-"${linux_stemcell_version}"-vsphere-esxi-ubuntu-"${linux_stemcell_name}"-go_agent.tgz)
  ubuntu_stemcell="${ubuntu_stemcells=[0]}"

  om upload-stemcell --stemcell "$ubuntu_stemcell" --floating=false --force
  om assign-stemcell --product cf --stemcell "$linux_stemcell_version"

  # Configure TAS
  om configure-product \
    --config /tmp/tas.yml \
    --var "apps_domain=${apps_domain}" \
    --var "system_domain=${sys_domain}" \
    --var "properties_networking_poe_ssl_certs_0_certificate.cert_pem=$(cat /tmp/wildcard.pem)" \
    --var "properties_networking_poe_ssl_certs_0_certificate.private_key_pem=$(cat /tmp/wildcard.key)" \
    --var "uaa_service_provider_key_credentials.cert_pem=$(cat /tmp/wildcard.pem)" \
    --var "uaa_service_provider_key_credentials.private_key_pem=$(cat /tmp/wildcard.key)"


  if $install_tasw; then
    # inject the TASW tile if not already injected
    if [ ! -f "${HOME}/Downloads/pas-windows-injected.pivotal" ]; then
      injector_zips=("${HOME}"/Downloads/winfs-injector-*.zip)
      injector_zip="${injector_zips=[0]}"

      tasw_tiles=("${HOME}"/Downloads/pas-windows-*.pivotal)
      tasw_tile="${tasw_tiles=[0]}"

      unzip -o "${injector_zip}" -d "${HOME}/Downloads/winfs-injector"
      pushd "${HOME}/Downloads/winfs-injector"
      chmod +x ./winfs-injector-linux
      ./winfs-injector-linux --input-tile "${tasw_tile}" --output-tile "${HOME}/Downloads/pas-windows-injected.pivotal"
      popd
    fi

    # upload injected TASW tile
    om upload-product -p "${HOME}/Downloads/pas-windows-injected.pivotal"
    om stage-product --product-name=pas-windows --product-version="${tile_version}"

    # upload missing stemcell
    win_stemcells=("${HOME}"/Downloads/bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz)
    win_stemcell="${win_stemcells=[0]}"
    om upload-stemcell -s "${win_stemcell}" --floating=true

    # Configure TASW
    om configure-product --config /tmp/tasw.yml
  fi


   # One big apply change
  om apply-changes 

}

function remote::configureAndDeployPostgres {
  scpFile ./postgres.yml /tmp/postgres.yml
  remoteExec 'configureAndDeployPostgres' "$@"
}

function configureAndDeployPostgres {
  local opsman_host="$1"
  local om_password="$2"
  local postgres_version="$3"
  local tcp_fqdn="$4"

  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

  tile_version=$(tanzuNetFileVersion "$postgres_version")

  tile_prefix='postgres'

  postgres_tile=$(findDownloadedOpsmanTile "${HOME}/Downloads" "$tile_prefix" "$tile_version")
  # upload and stage the tile
  om -r=10800 --trace upload-product -p "$postgres_tile"  

  build_ver=$(om products -a -f json | jq -r '.[] | select(.name == "postgres") | .available | .[]')

  om stage-product --product-name=postgres --product-version="${build_ver}"

  # Configure TAS
  om configure-product \
    --config /tmp/postgres.yml \
    --var "tcp_fqdn=${tcp_fqdn}" \

  ## One apply change
  om apply-changes --product-name "postgres"
}

function remote::configureAndDeployGenAI {
  scpFile ./genai.yml /tmp/genai.yml
  scpFile ./genaitkgi.yml /tmp/genaitkgi.yml
  remoteExec 'configureAndDeployGenAI' "$@"
}

function configureAndDeployGenAI {
  local opsman_host="$1"
  local om_password="$2"
  local genai_version="$3"
  local install_tkgi="$4"
  local tkgi_api_host="$5"
  local cluster_name="tkgiclustergenai1"

  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"


  if tkgi get-credentials "${cluster_name}"; then
    kubectl config use-context "${cluster_name}"
    kubectl create namespace genai-dev-space-1
    kubectl label namespace genai-dev-space-1 ai.apps.tanzu.vmware.com/integration=create
    # kubectl get secrets -n genai-dev-space-1 -l app.kubernetes.io/managed-by=genai-tpcf -o json | jq '.items[] | {name: .metadata.name,data: .data|map_values(@base64d)}'
  fi

  tile_version=$(tanzuNetFileVersion "$genai_version")

  tile_prefix='genai'

  genai_tile=$(findDownloadedGenaiTile "${HOME}/Downloads" "$tile_prefix" "$tile_version")

  # upload and stage the tile
  om -r=10800 --trace upload-product -p "$genai_tile"  
  om stage-product --product-name=genai --product-version="${genai_version}"

 
  # Configure GenAI

  if $install_tkgi; then

    om configure-product \
      --config /tmp/genai.yml

    # tkgi_admin_client_secret=$(om credentials -p pivotal-container-service -c '.properties.pks_uaa_management_admin_client' -t json | jq -r .secret)
    # om configure-product \
    #   --config /tmp/genaitkgi.yml \
    #   --var "tkgi_api_url=${tkgi_api_host}" \
    #   --var "tkgi_admin_client_secret=${tkgi_admin_client_secret}" 
  else

    om configure-product \
      --config /tmp/genai.yml
  fi

  # One apply change
  om apply-changes --product-name "genai"
}


function addCFLoginToDirEnv {
  local sys_domain="$1"

  if ! grep -q 'cf auth admin' .envrc 2> /dev/null; then
    cat >> .envrc <<EOF

# Login to CF dev org/space as admin
export CF_HOME="$(pwd)"
cf api "https://api.${sys_domain}" --skip-ssl-validation
cf auth admin "\$(om credentials -p cf -c '.uaa.admin_credentials' -t json | jq -r .password)"
if ! cf org dev > /dev/null; then cf create-org dev; fi
cf target -o dev
if ! cf space dev > /dev/null; then cf create-space dev; fi
cf target -s dev
EOF
  eval "$(direnv export bash)"
fi
}

function findTASProductConfigFile {
  local config_dir="$1"
  local tas_version="$2"
  local install_full_tas="$3"

  local product="srt"
  if $install_full_tas; then
    product="cf"
  fi

  major_minor="${tas_version%.*}"
  echo "${config_dir}/${product}-${major_minor}.yml"
}

function remote::configureAndDeployHealthwatch {
  scpFile ./healthwatch.yml /tmp/healthwatch.yml
  scpFile ./healthwatch-pas-exporter.yml /tmp/healthwatch-pas-exporter.yml
  scpFile ./healthwatch-pks-exporter.yml /tmp/healthwatch-pks-exporter.yml
  remoteExec 'configureAndDeployHealthwatch' "$@"
}

function configureAndDeployHealthwatch {
  local opsman_host="$1"
  local om_password="$2"
  local healthwatch_version="$3"
  local install_tkgi="$4"
  local install_genai="$5"

  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

  tile_version=$(tanzuNetFileVersion "$healthwatch_version")

  tile_prefix='healthwatch'
  healthwatch_tile=$(findDownloadedOpsmanTile "${HOME}/Downloads/" "$tile_prefix" "$tile_version")
  # upload and stage the tile
  om -r=10800 --trace upload-product -p "$healthwatch_tile"  
  build_ver=$(om products -a -f json | jq -r '.[] | select(.name == "p-healthwatch2") | .available | .[]')
  om stage-product --product-name=p-healthwatch2 --product-version="${build_ver}"
  om configure-product \
     --config /tmp/healthwatch.yml

  tile_prefix='healthwatch-pas-exporter'
  healthwatch_tile=$(findDownloadedOpsmanTile "${HOME}/Downloads/" "$tile_prefix" "$tile_version")
  # upload and stage the tile
  om -r=10800 --trace upload-product -p "$healthwatch_tile" 
  build_ver=$(om products -a -f json | jq -r '.[] | select(.name == "p-healthwatch2-pas-exporter") | .available | .[]')
  om stage-product --product-name=p-healthwatch2-pas-exporter --product-version="${build_ver}"
  om configure-product \
     --config /tmp/healthwatch-pas-exporter.yml

  if $install_tkgi; then
    tile_prefix='healthwatch-pks-exporter'
    healthwatch_tile=$(findDownloadedOpsmanTile "${HOME}/Downloads/" "$tile_prefix" "$tile_version")
    # upload and stage the tile
    om -r=10800 --trace upload-product -p "$healthwatch_tile"
    build_ver=$(om products -a -f json | jq -r '.[] | select(.name == "p-healthwatch2-pks-exporter") | .available | .[]')
    om stage-product --product-name=p-healthwatch2-pks-exporter --product-version="${build_ver}"
    om configure-product \
      --config /tmp/healthwatch-pks-exporter.yml
  fi

  ## One apply change
  if $install_tkgi; then
    om apply-changes --product-name p-healthwatch2 --product-name p-healthwatch2-pas-exporter --product-name p-healthwatch2-pks-exporter
  else
    om apply-changes --product-name p-healthwatch2 --product-name p-healthwatch2-pas-exporter
  fi

}