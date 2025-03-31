resource "nsxt_policy_ip_block" "tkgi-nodes-block" {
  display_name = "tkgi-nodes-block"
  nsx_id       = "tkgi-nodes-block"
  cidr         = "172.23.0.0/16"
}

resource "nsxt_policy_ip_block" "tkgi-pods-block" {
  display_name = "tkgi-pods-block"
  nsx_id       = "tkgi-pods-block"
  cidr         = "172.16.0.0/16"
}

resource "nsxt_policy_ip_pool" "tkgi-ingress-floating-pool" {
  display_name = "tkgi-ingress-floating-pool"
  nsx_id       = "tkgi-ingress-floating-pool"
}

resource "nsxt_policy_ip_pool" "tkgi-egress-floating-pool" {
  display_name = "tkgi-egress-floating-pool"
  nsx_id       = "tkgi-egress-floating-pool"
}

resource "nsxt_policy_ip_pool_static_subnet" "tkgi-ingress-floating-pool" {
  display_name = "tkgi-ingress-floating-pool"
  nsx_id       = "tkgi-ingress-floating-pool"
  pool_path    = nsxt_policy_ip_pool.tkgi-ingress-floating-pool.path
  cidr         = var.tkgi_nsxt_ingress_cidr
  gateway      = cidrhost(var.tkgi_nsxt_ingress_cidr, 1)

  allocation_range {
    start = cidrhost(var.tkgi_nsxt_ingress_cidr, 25)
    end   = cidrhost(var.tkgi_nsxt_ingress_cidr, 100)
  }
}

resource "nsxt_policy_ip_pool_static_subnet" "tkgi-egress-floating-pool" {
  display_name = "tkgi-egress-floating-pool"
  nsx_id       = "tkgi-egress-floating-pool"
  pool_path    = nsxt_policy_ip_pool.tkgi-egress-floating-pool.path
  cidr         = var.tkgi_nsxt_egress_cidr
  gateway      = cidrhost(var.tkgi_nsxt_egress_cidr, 1)

  allocation_range {
    start = cidrhost(var.tkgi_nsxt_egress_cidr, 70)
    end   = cidrhost(var.tkgi_nsxt_egress_cidr, 100)
  }
}