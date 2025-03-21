# Tanzu Platform for Cloud Foundry
Automation to install TPCF (small footprint runtime) in your homelab environment (VDS deployment type, no load balancers) & GenAI for TPCF

### Prerequisites
vCenter 7.x or superior, 3 routable Port Groups (here "Management", "Deployment", "Services" as default values) with Internet access, for example GenAI workers in the "Services" segment need to access/download AI models from the Internet

## Install TPCF
This script assumes you're running it from a Mac or Linux workstation connected
to your vCenter and the [jumpbox] is deployed.

To install TPCF, create a `tas.config` file from a copy of the `tasX.0.config_template` template, edit the values as needed with your environment variables, then run the installation:

```sh
./install.sh
```

This will use the already provisioned Jumpbox to run most of the heavy lifting
like downloading and uploading the Operations Manager OVA and TAS tile.

Once installation is complete the script generates an `.envrc` file for this
environment in the current `tpcf_vds` directory. If you have [direnv] installed
you can execute `direnv allow` which will setup the environment connection
variables for [om], [bosh], [CF] CLIs

You can then start using commands, for example:

List BOSH VMs
```sh
bosh vms
```

List OpsMan tiles
```sh
om products
```

List CF Orgs
```sh
cf orgs
```

To SSH to OpsMan
```sh
ssh -F ../jumpbox/.ssh/config opsman
```


## Install Postgres & GenAI tiles
This script assumes that TPFC is deployed

```sh
./install_genaiservices.sh
```

## Configuration
Edit the values as needed in the `tas.config` file.

```sh
tanzu_net_api_token='<your-api-token>'
homelab_domain='homelab.loc'
tas_subdomain='tas'
vcenter_host='vcenter.homelab.loc'
vcenter_datacenter='Homelab-Datacenter'
vcenter_cluster='Homelab-Cluster'
vcenter_username='administrator@vsphere.local'
vcenter_datastore='vsanDatastore'
vcenter_pool='tas'
dns_servers='10.50.0.10'
ntp_servers='time.cloudflare.com'
opsman_vm_name='ops-manager'
opsman_private_ip='10.50.0.20'
om_password='VMware1!'
infrastructure_network_identifier='Management'
infrastructure_nat_gateway_ip='10.50.0.1'
infrastructure_cidr='10.50.0.0/24'
infrastructure_reserved_ip_ranges='10.50.0.1-10.50.0.20'
deployment_network_identifier='Deployment'
deployment_nat_gateway_ip='10.70.0.1'
deployment_cidr='10.70.0.0/24'
deployment_reserved_ip_ranges='10.70.0.1-10.70.0.10'
services_network_identifier='Services'
services_nat_gateway_ip='10.80.0.1'
services_cidr='10.80.0.0/24'
services_reserved_ip_ranges='10.80.0.1-10.80.0.10'
gorouter_ip_range='10.70.0.11-10.70.0.13'
ssh_ip_range='10.70.0.14-10.70.0.16'
tcp_ip_range='10.70.0.17-10.70.0.19'
install_full_tas='false'
install_tasw='false'
xenial_stemcell_version='621.969'
jammy_stemcell_version='1.719'
windows_stemcell_version='2019.71'
opsman_version='3.0.37+LTS-T'
tas_version='10.0.2'
install_genai='true'
genai_version='10.0.2'
install_postgres='true'
postgres_version='1.1.2-build.6'
```


- `infrastructure_*` - specify the Infrastructure segment details
- `deployment_*` - specify the Deployment segment details
- `services_*` - specify the Services segment details
- `gorouter_ip_range` - specify static IP addresses for gorouter instances (HTTP protocols)
- `ssh_ip_range` - specify static IP addresses for TCP router instances (non-HTTP protocols)
- `tcp_ip_range` - specify static IP addresses for control plane components
- `tas_version` - the TAS version to deploy, versions 4.0.x through 10.0.2 are supported.
- `install_full_tas` - when true the full (large) version of TPCF is deployed, otherwise the TPCF small footprint version. (not yet functional)
- `install_tasw` - when true TPCF is deployed with the Windows stack. (not yet functional)

After completing your edits, run the install script:
```bash
./install.sh
```

## Destroy TPCF

To destroy the TPCF deployment run

```bash
./destroy.sh
```

[direnv]: https://direnv.net/
[om]: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-operations-manager/3-0/tanzu-ops-manager/install-cli.html
[bosh]: https://bosh.io/docs/cli-v2-install/
[CF]: https://docs.cloudfoundry.org/cf-cli/install-go-cli.html
[jumpbox]: ../jumpbox/README.md

