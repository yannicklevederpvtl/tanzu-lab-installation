# Tanzu Platform for Cloud Foundry
Automation to install TPCF (small footprint runtime) in your homelab environment (NSX-T deployment type) and optionally GenAI for TPCF or/and TKGI (Tanzu Kubenetes Grid Integrated) with the [beta] GenAI Inegration for your k8s clusters. 

### Prerequisites
vCenter 7.x or superior, one routable Port Groups (here "Management" as default value), an NSX T0 with BGP and Internet access properly configured, for example GenAI workers in the "Services" segment need to access/download AI models from the Internet. The script will Terraform all the T1, LBs, Pools, etc. and deploy the platform.

## Install TPCF
This script assumes you're running it from a Mac or Linux workstation connected
to your vCenter and the [jumpbox] is deployed.

To install TPCF, create a `tas.config` file from a copy of the desired version `tasX.0.config_template` template, edit the values as needed with your environment variables (see [configuration]), then run the installation:

```sh
./install.sh
```

This will use the already provisioned Jumpbox to run most of the heavy lifting
like downloading and uploading the OpsMan OVA and TPCF tile.

Once installation is complete the script generates an `.envrc` file for this
environment in the current `tpcf_nsx` directory. If you have [direnv] installed
you can execute `direnv allow` which will setup the environment connection
variables for [om], [bosh], [CF], [tkgi] CLIs

You can then start using commands from your workstation in the current `tpcf_nsx` directory, for example:

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

To access Apps Manager GUI (`admin` as username, `In the OpsMan GUI -> TPCF Tile -> Credentials tab -> UAA section -> Admin Credentials` as password)
```sh
https://login.sys.<tas_subdomain>.<homelab_domain>
```

## Install TKGI
Set the `install_tkgi` value to `true` in the `tas.config` file before running the TPCF `./install.sh` script

List TKGI clusters
```sh
tkgi clusters
```

## Install Postgres & GenAI tiles
This script assumes that TPFC is deployed

Set the `install_genai` value to `true` in the `tas.config` file

```sh
./install_genaiservices.sh
```

## Install Healthwatch tiles
Set the `install_healthwatch` value to `true` in the `tas.config` file before running the TPCF `./install.sh` script

## Install Hub Collector tile
Set the `install_hubcollector` value to `true` in the `tas.config` file before running the TPCF `./install_hubcollector.sh` script

Use `extras/add_hubtascollector_users.sh` to create [hubcollector] users before configuring the Hub Collector tile with user credentials and Hub credentials


## Configuration
Edit the values as needed in the `tas.config` file

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
nsxt_host='nsxmanager.homelab.loc'
nsxt_username='admin'
nsxt_password='VMware1!VMware1!'
nsxt_edgecluster_name='EdgeCluster'
nsxt_t0_gw_name='Tier-0 GW-0'
nsxt_tz_name='nsx-overlay-TZ'
dns_servers='10.50.0.100'
ntp_servers='time.cloudflare.com'
opsman_vm_name='ops-manager'
opsman_private_ip='192.168.11.3'
opsman_gateway='192.168.11.1'
om_password='VMware1!'
tas_infrastructure_nat_gateway_ip='10.60.0.65'
tas_deployment_nat_gateway_ip='10.60.0.66'
tas_services_nat_gateway_ip='10.60.0.67'
tas_ops_manager_public_ip='10.90.0.17'
tas_lb_web_virtual_server_ip_address='10.90.0.18'
tas_lb_tcp_virtual_server_ip_address='10.90.0.19'
tas_lb_ssh_virtual_server_ip_address='10.90.0.20'
install_full_tas='false'
install_tasw='false'
xenial_stemcell_version='621.969'
jammy_stemcell_version='1.824'
opsman_version='3.1.0'
tas_version='10.2.0'
tas_licensekey='xxxxx-xxxxx-xxxxx-xxxxx-xxxxx'
install_genai='true'
genai_version='10.2.0'
install_postgres='true'
postgres_version='10.1.0'
install_tkgi='true'
tkgi_version='1.22.1'
tkgi_lb_api_virtual_server_ip_address='10.90.0.21'
tkgi_deployment_nat_gateway_ip='10.60.0.68'
tkgi_service_cidr='10.100.200.0/24'
tkgi_nsxt_ingress_cidr='10.90.0.0/24'
tkgi_nsxt_egress_cidr='10.60.0.0/24'
install_healthwatch='true'
healthwatch_version='2.3.2'
install_hubcollector='false'
hubcollector_version='10.2.2'
```

- `tas_infrastructure_nat_gateway_ip` is the SNAT IP for all VMs on the private infrastructure network,
by default Operations Manager and the BOSH director (nsxt-egress).
- `tas_deployment_nat_gateway_ip` is the SNAT IP for all TPCF VMs, so things like Diego cells, GoRouters,
Cloud Controller etc (nsxt-egress).
- `tas_services_nat_gateway_ip` is the SNAT IP for all optional service tile VMs, for example the Postgres tile (nsxt-egress).
- `tas_ops_manager_public_ip` is the DNAT IP address for Operations Manager that is reachable from
the VMware network. This is the IP address your `opsman` DNS entry should point to (nsxt-ingress).
- `tas_lb_web_virtual_server_ip_address` is the DNAT IP address for the NSX-T ingress load balancer that
sits in from of the TPCF GoRouters. This is how the Cloud Controller and application's running on TAS are accessed.
This is the IP address that your `*.apps` and `*.sys` DNS entries should point to (nsxt-ingress).
- `tas_lb_tcp_virtual_server_ip_address` is the DNAT IP address if you're using TCP routing in TPCF (nsxt-ingress).
- `tas_lb_ssh_virtual_server_ip_address` is the DNAT IP address when using `cf ssh` to SSH into running app instances (nsxt-ingress).
- `nsxt_t0_gw_name` is the name of your T0 in NSX
- `nsxt_tz_name` is the name of your transport zone in NSX
- `opsman_version` - the version of Operations Manager to deploy
- `tas_version` - the TPCF version to deploy, versions 4.0.x through 10.0.2 are supported.
- `install_full_tas` - when true the full (large) version of TPCF is deployed, otherwise the TPCF small footprint version. (not yet functional)
- `install_tasw` - when true TPCF is deployed with the Windows stack. (not yet functional)
- `install_tkgi` - when true TKGI is deployed with the TPCF stack
- `tkgi_lb_api_virtual_server_ip_address` is the DNAT IP address for the TKGI API. This is the IP address
the `tkgi-api` DNS entry should point to.
- `tkgi_deployment_nat_gateway_ip` is the SNAT IP for all TKGI k8s cluster VMs (nsxt-egress).
- `tkgi_nsxt_ingress_cidr`is the IP range for any NSX-T ingress load balancer that sits in front of
your k8s clusters. The first 25 IPs of this range are reserved for OpsMan, TAS & TKGI API.
TKGI will configure a floating IP pool using IPs of this range for LBs and namespaces, so in this example 10.90.0.25 -> 10.90.0.100
- `tkgi_nsxt_egress_cidr` is the IP range for any NSX-T egress. The first 70 IPs are reserved for SNAT from the TAS & TKGI infra and deployment networks.
TKGI will take 31 IPs from this subnet to be used as another floating IP pool for TKGI, so in this example 10.60.0.70 -> 10.60.0.100
- `tkgi_deployment_nat_gateway_ip` is the SNAT IP for all TKGI k8s cluster VMs

After completing your edits, run the install script:
```bash
./install.sh
```

## Destroy TPCF

To destroy the TPCF deployment run (if TKGI,  delete your TKGI clusters first)

```bash
./destroy.sh
```

[direnv]: https://direnv.net/
[om]: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-operations-manager/3-0/tanzu-ops-manager/install-cli.html
[bosh]: https://bosh.io/docs/cli-v2-install/
[CF]: https://docs.cloudfoundry.org/cf-cli/install-go-cli.html
[tkgi]: https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-kubernetes-grid-integrated-edition/1-20/tkgi/installing-cli.html
[jumpbox]: ../jumpbox/README.md
[configuration]: #configuration
[beta]: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform-services/genai-on-tanzu-platform-for-cloud-foundry/10-0/ai-cf/tutorials-tkgi.html
[hubcollector]: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-hub/10-2/tnz-hub/foundations-overview.html