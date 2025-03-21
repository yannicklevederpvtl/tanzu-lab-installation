data "cloudinit_config" "harbor_userdata" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "cloud-config.yml"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-config.yml.tftpl", {
      password:         var.password
      ssh_public_key:   var.ssh_public_key
      harbor_host:      var.harbor_host
      provision_script: base64encode(file("${path.module}/provision.sh"))
      harbor_config:    base64encode(templatefile("${path.module}/harbor.yml.tftpl", {
        harbor_host:    var.harbor_host
        password:       var.password
      }))
    })
  }
}

resource "vsphere_virtual_machine" "harbor" {
  name             = var.vm_name
  datacenter_id    = data.vsphere_datacenter.dc.id
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  host_system_id   = data.vsphere_host.host.id
  num_cpus         = 2
  memory           = var.ram
  
  ovf_deploy {
    allow_unverified_ssl_cert = false
    remote_ovf_url            = "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.ova"
    ovf_network_map           = {
      "VM Network" = data.vsphere_network.network.id
    }
  }

  disk {
    label            = "disk0"
    size             = var.disk_size
    thin_provisioned = true
    io_share_count   = 1000
  }

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  extra_config = {
    "guestinfo.userdata.encoding" = "gzip+base64"
    "guestinfo.userdata"          = data.cloudinit_config.harbor_userdata.rendered
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.metadata"          = base64encode(templatefile("${path.module}/metadata.yml.tftpl", {
      vm_name:           var.vm_name
      ip_address:        var.ip_address
      network_cidr_bits: var.network_cidr_bits
      gateway:           var.gateway
      nameservers:       jsonencode(var.nameservers)
    }))
  }
}
