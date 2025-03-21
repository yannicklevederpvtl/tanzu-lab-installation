# Harbor
Automation to create a Harbor registry in your homelab environment.


## Create Harbor
This script assumes you're running it from a Mac or Linux workstation connected
to your vCenter and the [jumpbox] is deployed.


To create a Harbor registry, create a `harbor.config` file from a copy of the `harbor.config_template` template, edit the values as needed with your environment variables (see [configuration]) and then execute the install:

```sh
./install.sh
```

This will download the latest Ubuntu Jammy OVA and spin up a Harbor VM in
your vSphere environment.

## Create DNS A Record 

Once the VM is deployed, create an A record in your DNS server based your environment variables 

```bash
<harbor_host> A <harbor_ip>
```

## Configuration

Edit the values as needed in the `harbor.config` file

```bash
# Required
homelab_domain='homelab.loc'
vcenter_host='vcenter.homelab.loc'
vcenter_username='administrator@vsphere.local'
vcenter_password='VMware1!'
vcenter_datacenter='Homelab-Datacenter'
vcenter_cluster='Homelab-Cluster'
vm_network='Management'
datastore='vsanDatastore'
harbor_ip='10.50.0.15'
harbor_gateway='10.50.0.1'
harbor_dns='10.50.0.10'

# Optional - overrides defaults
harbor_netmask='255.255.255.0'
vm_name='harbor'
root_disk_size='80G'
ram='8192'
```

- `homelab_domain` is the domain suffix your homelab.
- `vcenter_host` is the FQDN or IP of your vCenter.
- `vcenter_username` is the administrator username of your vCenter.
- `vcenter_password` is the administrator password of your vCenter.
- `vcenter_datacenter` is the datacenter in your vCenter where harbor is deployed.
- `vcenter_cluster` is the cluster in your vCenter where harbor is deployed.
- `vcenter_password` is the administrator password of your vCenter.
- `harbor_ip` is the IP address of harbor.
- `harbor_netmask` is the network mask used by harbor.
- `harbor_gateway` is the network gateway used by harbor.
- `harbor_dns` is the comma delimited list of DNS servers used by harbor.
- `vcenter_host` is the vCenter host name that is used by govc to spin up harbor.
- `vm_name` is the VM name, by default harbor.
- `vm_network` is the network name harbor is attached to, by default Management.
- `root_disk_size` is the size of the harbor HDD, by default 80G.
- `datastore` is the vCenter datastore name.
- `ram` is the amount of RAM to give harbor, by default this is 8192 (8G).

After completing your edits, run the install script:
```sh
./install.sh
```


## Destroy Harbor

To destroy Harbor run

```bash
./destroy.sh
```

[jumpbox]: ../jumpbox/README.md
[configuration]: #configuration
