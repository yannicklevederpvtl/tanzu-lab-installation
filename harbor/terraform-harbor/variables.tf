variable "vsphere_user" {
  description = "The vsphere_user"
  default     = "administrator@vsphere.local"
  type        = string
}

variable "vsphere_password" {
  description = "The vsphere password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "The vsphere server"
  type        = string
}

variable "esxi_host" {
  description = "ESXI Host"
  type        = string
}

variable "allow_unverified_ssl" {
  description = "Allow connection to vCenter with self-signed certificates. Set to `true` for POC or development environments"
  default     = false
  type        = bool
}

variable "vsphere_datacenter" {
  description = "vsphere datacenter name"
  default     = "vcenter01"
  type        = string
}

variable "vsphere_datastore" {
  description = "vsphere datastore name"
  default     = "vsanDatastore"
  type        = string
}

variable "vsphere_cluster" {
  description = "vsphere compute cluster name"
  default     = "cluster01"
  type        = string
}

variable "vsphere_network" {
  description = "vsphere network name"
  default     = "user-workload"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "harbor_host" {
  description = "Harbor public host FQDN"
  type        = string
}

variable "ip_address" {
  description = "Harbor IPv4 address"
  type        = string
}

variable "network_cidr_bits" {
  description = "Harbor IPv4 subnet mask - CIDR bits"
  default     = "27"
  type        = string
}

variable "gateway" {
  description = "Harbor IPv4 network gateway address"
  type        = string
}

variable "nameservers" {
  description = "Harbor IPv4 DNS name servers"
  default     = ["1.1.1.1"]
  type        = list(string)
}

variable "password" {
  description = "Harbor password"
  type        = string
  sensitive   = true
}

variable "vm_name" {
  description = "Harbor VM name"
  default     = "harbor"
  type        = string
}

variable "disk_size" {
  description = "Harbor VM disk size in GB"
  default     = 100
  type        = number
}

variable "ram" {
  description = "Harbor VM RAM"
  default     = 4196
  type        = number
}

