# Tanzu Platform for Cloud Foundry
Automation to download & install TPCF (small footprint runtime) in your homelab environment (VDS deployment type, no load balancers) & GenAI for TPCF

### Prerequisites
vCenter 7.x or superior, 3 routable Port Groups (for example "Management", "Deployment", "Services" as default values, see [configuration] to customize it as needed) with Internet access, for example GenAI workers in the "Services" segment need to access/download AI models from the Internet

## Install TPCF
This script assumes you're running it from a Mac or Linux workstation connected
to your vCenter and the [jumpbox] is deployed.

To install TPCF, create a `tas.config` file from a copy of the `tasX.0.config_template` template, edit the values as needed with your environment variables (see [configuration]), then run the installation:

```sh
./install.sh
```

This will use the already provisioned Jumpbox to run most of the heavy lifting
like downloading and uploading the OpsMan OVA and TPCF tile.

Once installation is complete the script generates an `.envrc` file for this
environment in the current `tpcf_vds` directory. If you have [direnv] installed
you can execute `direnv allow` which will setup the environment connection
variables for [om], [bosh], [CF] CLIs

You can then start using commands from your workstation in the current `tpcf_vds` directory, for example:

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

To access OpsMan GUI (`admin` as username, `<om_password>` as password)
```sh
https://opsman.<tas_subdomain>.<homelab_domain>
```

To access Apps Manager GUI (`admin` as username, `In the OpsMan GUI -> TAS Tile -> Credentials tab -> UAA section -> Admin Credentials` as password)
```sh
https://login.sys.<tas_subdomain>.<homelab_domain>
```

## Install Postgres & GenAI tiles
This script assumes that TPCF is deployed

```sh
./install_genaiservices.sh
```

## Install Healthwatch tiles
Set the `install_healthwatch` value to `true` in the `tas.config` file before running the TPCF `./install.sh` script


## Install Hub Collector tile
Set the `install_hubcollector` value to `true` in the `tas.config` file before running the TPCF `./install_hubcollector.sh` script

Use the `extras/add_hubtascollector_users.sh` script to create [hubcollector] users (in BOSH Director and Opsman) before finishing to configure the Hub Collector tile with these user credentials and the foundation credentials provided when adding a foundation in Hub

Use `../jumpbox/.ssh/config` as Opsman SSH config file path when asked, `hub-tas-collector` is used as default username for both users


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
jammy_stemcell_version='1.824'
windows_stemcell_version='2019.71'
opsman_version='3.1.0'
tas_version='10.2.0'
tas_licensekey='xxxxx-xxxxx-xxxxx-xxxxx-xxxxx'
install_genai='true'
genai_version='10.2.0'
install_postgres='true'
postgres_version='10.1.0'
install_healthwatch='false'
healthwatch_version='2.3.2'
install_hubcollector='false'
hubcollector_version='10.2.2'
```


- `infrastructure_*` - specify the Infrastructure segment details
- `deployment_*` - specify the Deployment segment details
- `services_*` - specify the Services segment details
- `gorouter_ip_range` - specify static IP addresses for gorouter instances (HTTP protocols)
- `ssh_ip_range` - specify static IP addresses for TCP router instances (non-HTTP protocols)
- `tcp_ip_range` - specify static IP addresses for control plane components
- `opsman_private_ip` - OpsMan IP address (direclty exposed in this VDS topology without LB)
- `tas_version` - the TPCF version to deploy, versions 4.0.x through 10.0.2 are supported.
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
[configuration]: #configuration
[hubcollector]: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-hub/10-2/tnz-hub/foundations-connect-foundation.html#get-creds

