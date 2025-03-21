#!/usr/bin/env bash

set -e
set -u
set -o pipefail


function ensureRunningAsRoot() {
  # script requires running as root, for example via cloud-init
  if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit 1
  fi
}

function waitForNetwork() {
  # wait for the network to come up
  # specifically DNS is broken for a couple of minutes for an unknown reason during cloud-init
  while ! ping -c 4 1.1.1.1 > /dev/null; do 
    echo "The network is not up yet, waiting 5s..."
    sleep 5 
  done
}

function installHarborPrereqs() {
  # install some prereqs
  apt-get update
  apt-get -y install apt-transport-https ca-certificates curl gnupg software-properties-common golang-go

  # add Docker's official GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # add the Docker repository to apt sources:
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update

  # install Docker packages
  apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose
}

function createAndInstallTLSCert() {
  local harbor_hostname="$1"

  # create CA certificate
  openssl req \
    -newkey rsa:4096 -nodes -sha256 -keyout harbor_ca.key \
    -x509 -days 365 -out harbor_ca.crt -subj '/C=CN/ST=CA/L=PaloAlto/O=VMware/CN=HarborCA'

  # generate a CSR
  openssl req \
    -newkey rsa:4096 -nodes -sha256 -keyout "$harbor_hostname.key" \
    -out "$harbor_hostname.csr" -subj "/C=CN/ST=CA/L=PaloAlto/O=VMware/CN=$harbor_hostname"

  # generate certificate for local registry host
  echo "subjectAltName = DNS.1:$harbor_hostname" > extfile.cnf
  openssl x509 -req -sha256 -days 365 \
    -extfile extfile.cnf \
    -CA harbor_ca.crt -CAkey harbor_ca.key -CAcreateserial \
    -in "$harbor_hostname.csr" \
    -out "$harbor_hostname.crt"

  # make cert available to Harbor
  mkdir -p /data/cert/
  mkdir -p /data/ca_download/
  cp "$harbor_hostname.crt" /data/cert/
  cp "$harbor_hostname.key" /data/cert/
  cp harbor_ca.crt /data/ca_download/ca.crt

  # convert cert to Docker compatible format
  openssl x509 -inform PEM -in "$harbor_hostname.crt" -out "$harbor_hostname.cert"

  # copy certs into Docker folder
  mkdir -p "/etc/docker/certs.d/$harbor_hostname/"
  cp "$harbor_hostname.cert" "/etc/docker/certs.d/$harbor_hostname/"
  cp "$harbor_hostname.key" "/etc/docker/certs.d/$harbor_hostname/"
  cp harbor_ca.crt "/etc/docker/certs.d/$harbor_hostname/ca.crt"
}

function installHarbor() {
  local version="$1"
  
  # download harbor and extract
  wget -nv "https://github.com/goharbor/harbor/releases/download/$version/harbor-offline-installer-$version.tgz"
  tar xvf "harbor-offline-installer-$version.tgz"

  # execute harbor installer
  # assumes untarred to harbor folder and harbor.yml already written by cloud-init
  cd harbor
  ./install.sh
}

function main() {
  local harbor_hostname="$1"

  ensureRunningAsRoot
  waitForNetwork
  installHarborPrereqs
  createAndInstallTLSCert "$harbor_hostname"
  installHarbor 'v2.12.2'
}

main "$1"
