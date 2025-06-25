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

function remote::downloadTanzuNetHubCollectorPackage {
  remoteExec 'downloadTanzuNetHubCollectorPackage' "$@"
}

function downloadTanzuNetHubCollectorPackage {
  local tanzu_net_api_token="$1"
  local hubcollector_version="$2"

  tile_glob="hub-tas-collector-${hubcollector_version}*.pivotal"
  om download-product -p tanzu-foundation-connector \
  -t "${tanzu_net_api_token}" \
  -f "${tile_glob}" \
  --product-version "${hubcollector_version}" \
  -o ~/Downloads

}

function remote::configureAndDeployHubCollector {
  scpFile ./hubcollector.yml /tmp/hubcollector.yml
  remoteExec 'configureAndDeployHubCollector' "$@"
}

function configureAndDeployHubCollector {
  local opsman_host="$1"
  local om_password="$2"
  local hubcollector_version="$3"

  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

  tile_version=$(tanzuNetFileVersion "$hubcollector_version")
  tile_prefix='hub-tas-collector'

  hubtascollector_tile=$(findDownloadedGenaiTile "${HOME}/Downloads" "$tile_prefix" "$tile_version")
  # upload and stage the tile
  om -r=10800 --trace upload-product -p "$hubtascollector_tile"  

  build_ver=$(om products -a -f json | jq -r '.[] | select(.name == "hub-tas-collector") | .available | .[]')

  om stage-product --product-name=hub-tas-collector --product-version="${build_ver}"

  # Configure TAS
  om configure-product \
   --config /tmp/hubcollector.yml

  ## One apply change
  # om apply-changes --product-name "hub-tas-collector"
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

    tkgi_admin_client_secret=$(om credentials -p pivotal-container-service -c '.properties.pks_uaa_management_admin_client' -t json | jq -r .secret)

    om configure-product \
      --config /tmp/genaitkgi.yml \
      --var "tkgi_api_url=${tkgi_api_host}" \
      --var "tkgi_admin_client_secret=${tkgi_admin_client_secret}" 
  else

    om configure-product \
      --config /tmp/genai.yml
  fi

  # One apply change
  om apply-changes --product-name "genai"
}


function remote::configureAndDeployHubcollector {
  scpFile ./hubcollector.yml /tmp/hubcollector.yml
  remoteExec 'configureAndDeployHubcollector' "$@"
}

function configureAndDeployHubcollector {
  local opsman_host="$1"
  local om_password="$2"
  local hubcollector_version="$3"

  # Set om connection info
  export \
    OM_USERNAME='admin' \
    OM_PASSWORD="${om_password}" \
    OM_DECRYPTION_PASSPHRASE="${om_password}" \
    OM_SKIP_SSL_VALIDATION='true' \
    OM_TARGET="${opsman_host}"

  tile_version=$(tanzuNetFileVersion "$hubcollector_version")

  tile_prefix='hub-tas-collector'

  hubcollector_tile=$(findDownloadedOpsmanTile "${HOME}/Downloads" "$tile_prefix" "$tile_version")
  # upload and stage the tile
  om -r=10800 --trace upload-product -p "$hubcollector_tile"  

  # build_ver=$(om products -a -f json | jq -r '.[] | select(.name == "postgres") | .available | .[]')

  # om stage-product --product-name=postgres --product-version="${build_ver}"

  # Configure TAS
  # om configure-product \
  #   --config /tmp/postgres.yml \
  #   --var "tcp_fqdn=${tcp_fqdn}" \

  ## One apply change
  # om apply-changes --product-name "postgres"
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