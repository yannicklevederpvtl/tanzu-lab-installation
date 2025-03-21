#!/usr/bin/env bash
set -e
set -u
set -o pipefail

function installOm {
  if [ ! -f /usr/local/bin/om ]; then
    echo "Installing om"
    wget -q https://github.com/pivotal-cf/om/releases/download/7.15.0/om-linux-amd64-7.15.0
    sudo install om-linux-amd64-7.15.0 /usr/local/bin/om
    rm -f om-linux-amd64-7.15.0
  fi
}

function installJq {
  if [ ! -f /usr/local/bin/jq ]; then
    echo "Installing jq"
    wget -q https://github.com/stedolan/jq/releases/download/jq-1.7.1/jq-linux64
    sudo install jq-linux64 /usr/local/bin/jq
    rm -f jq-linux64
  fi
}

function installTerraform {
  if [ ! -f /usr/local/bin/terraform ]; then
      echo "Installing terraform"
      wget -q https://releases.hashicorp.com/terraform/1.11.2/terraform_1.11.2_linux_amd64.zip
      unzip terraform_1.11.2_linux_amd64.zip
      sudo install terraform /usr/local/bin/terraform
      rm -f terraform_1.11.2_linux_amd64.zip
      rm -f terraform
  fi
}

function installGovc {
  if [ ! -f /usr/local/bin/govc ]; then
      echo "Installing govc"
      wget -q https://github.com/vmware/govmomi/releases/download/v0.49.0/govc_Linux_x86_64.tar.gz
      tar -xf govc_Linux_x86_64.tar.gz
      sudo install govc /usr/local/bin/govc
      rm -f govc_Linux_x86_64.tar.gz
      rm -f govc
      rm -f CHANGELOG.md
      rm -f LICENSE.txt
      rm -f README.md
  fi
}

function installYtt {
  if [ ! -f /usr/local/bin/ytt ]; then
      echo "Installing ytt"
      wget -q https://github.com/vmware-tanzu/carvel-ytt/releases/download/v0.51.1/ytt-linux-amd64
      sudo install ytt-linux-amd64 /usr/local/bin/ytt 
      rm -f ytt-linux-amd64
  fi
}

function installDocker {
  echo "Installing docker"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo apt-get -qq update
  sudo apt-get -qq install -y ca-certificates curl gnupg lsb-release jq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo usermod -aG docker ubuntu
}

function installKind {
  if [ ! -f /usr/local/bin/kind ]; then
      echo "Installing kind"
      wget -q https://kind.sigs.k8s.io/dl/v0.14.0/kind-linux-amd64
      sudo install kind-linux-amd64 /usr/local/bin/kind
      rm -f kind-linux-amd64
  fi
}

function installBosh {
  if [ ! -f /usr/local/bin/bosh ]; then
      echo "Installing bosh"
      wget -q https://github.com/cloudfoundry/bosh-cli/releases/download/v7.9.4/bosh-cli-7.9.4-linux-amd64
      sudo install bosh-cli-7.9.4-linux-amd64 /usr/local/bin/bosh
      rm -f bosh-cli-7.9.4-linux-amd64
  fi
}

function installZip {
    # Required for surgery on .pivotal files
    if [ ! -f /usr/bin/zip ]; then
        echo "Installing zip"
        sudo apt-get -qq update
        sudo apt-get -qq install -y zip
    fi
}

function installPowershell {
    # Required for AVI installation
    if [ ! -d /snap/powershell ]; then
        echo "Installing powershell"
        sudo apt-get -qq update
        sudo apt-get -qq upgrade
        sudo apt-get -qq dirmngr lsb-release ca-certificates software-properties-common apt-transport-https curl -y
        curl -fSsL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor | sudo tee /usr/share/keyrings/powershell.gpg > /dev/null
        echo "deb [arch=amd64,armhf,arm64 signed-by=/usr/share/keyrings/powershell.gpg] https://packages.microsoft.com/ubuntu/20.04/prod/ focal main" | sudo tee /etc/apt/sources.list.d/powershell.list
        sudo apt-get -qq update
        sudo snap install powershell --classic
        cat > installpwcli.ps1 <<EOF
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name VMware.PowerCLI -Force
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$false -Confirm:\$false
Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction:Ignore -Confirm:\$false
Get-Module -ListAvailable VMware*
EOF
        powershell ./installpwcli.ps1
    fi
}

function installOVFtool {
    # Required for surgery on OVA image files
    if [ ! -f /usr/local/bin/ovftool ]; then
        echo "Installing OVF Tool"
        wget -q https://github.com/rgl/ovftool-binaries/raw/main/archive/VMware-ovftool-4.6.3-24031167-lin.x86_64.zip
        unzip VMware-ovftool-4.6.3-24031167-lin.x86_64.zip
        sudo mv ./ovftool/ /usr/local/bin/ovf/
        sudo chmod +x /usr/local/bin/ovf/ovftool.bin
        sudo chmod +x /usr/local/bin/ovf/ovftool
        sudo ln -s /usr/local/bin/ovf/ovftool /usr/local/bin/ovftool
        rm -f VMware-ovftool-4.6.3-24031167-lin.x86_64.zip
    fi
}