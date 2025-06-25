#!/usr/bin/env bash
set -e
set -u
set -o pipefail

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


function remote::configureAndDeployTAS {
  local tas_version="$5"
  local install_full_tas="$8"

  config_file=$(findTASProductConfigFile "${HELPER_DIR}/tpcf_vds/cf" "$tas_version" "$install_full_tas")
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
  local tas_licensekey="${10}"

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
  echo "$tas_tile"
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
    --var "tas_licensekey=${tas_licensekey}" \
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
