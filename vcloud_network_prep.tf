resource "vcd_vapp" "k8s_mgmt_vapp" {
  name = var.vcloud.vapp_name

  metadata = {
    tag = "MGMT K8s"
  }
}

resource "vcd_vapp_org_network" "vappOrgNet" {
  depends_on = [vcd_vapp.k8s_mgmt_vapp]

  org              = var.vcloud.orgname
  vdc              = var.vcloud.vdc
  vapp_name        = var.vcloud.vapp_name
  org_network_name = var.vcloud.orgvnet_name
}

# ---------------------------------------------------------------
# NSX-T ALB: Edge Gateway and Service Engine Group
# ---------------------------------------------------------------
data "vcd_nsxt_alb_edgegateway_service_engine_group" "alb" {
  org = var.vcloud.orgname
  vdc = var.vcloud.vdc

  edge_gateway_id           = data.vcd_nsxt_edgegateway.egw.id
  service_engine_group_name = "LB-POD01_Shared_SE01"
}

# ---------------------------------------------------------------
# Kubernetes API: master nodes TCP/6443
# ---------------------------------------------------------------

resource "vcd_nsxt_alb_pool" "kube_api_pool" {
  org             = var.vcloud.orgname
  name            = "kube-api-pool"
  edge_gateway_id = data.vcd_nsxt_edgegateway.egw.id

  algorithm    = "ROUND_ROBIN"
  default_port = 6443

  health_monitor {
    type = "TCP"
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.m_node)
    )
    port = 6443
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.m_node) + 1
    )
    port = 6443
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.m_node) + 2
    )
    port = 6443
  }
}

resource "vcd_nsxt_alb_virtual_service" "kube_api" {
  org             = var.vcloud.orgname
  name            = "kube-api"
  edge_gateway_id = data.vcd_nsxt_edgegateway.egw.id

  pool_id = vcd_nsxt_alb_pool.kube_api_pool.id

  service_engine_group_id = (
    data.vcd_nsxt_alb_edgegateway_service_engine_group.alb.service_engine_group_id
  )

  virtual_ip_address = cidrhost(
    var.os_config.vm_ip_cidr,
    tonumber(var.ip_plan.kubeapi_lb)
  )

  application_profile_type = "L4"

  service_port {
    start_port = 6443
    type       = "TCP_PROXY"
  }
}

# ---------------------------------------------------------------
# Kubernetes Ingress: HTTP (порт 80 -> пул с HTTP NodePort)
# ---------------------------------------------------------------

resource "vcd_nsxt_alb_pool" "ingress_http_pool" {
  org             = var.vcloud.orgname
  name            = "ingress-http-pool"
  edge_gateway_id = data.vcd_nsxt_edgegateway.egw.id

  algorithm    = "ROUND_ROBIN"
  default_port = tonumber(
    var.kubernetes.ingress.controller_nodeport_http
  )

  # Привязка системных мониторов
  health_monitor {
    name = "System-Ping"
  }
  health_monitor {
    name = "System-TCP"
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.w_node)
    )
    port = tonumber(
      var.kubernetes.ingress.controller_nodeport_http
    )
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.w_node) + 1
    )
    port = tonumber(
      var.kubernetes.ingress.controller_nodeport_http
    )
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.w_node) + 2
    )
    port = tonumber(
      var.kubernetes.ingress.controller_nodeport_http
    )
  }
}

resource "vcd_nsxt_alb_virtual_service" "ingress_http" {
  org             = var.vcloud.orgname
  name            = "ingress-http"
  edge_gateway_id = data.vcd_nsxt_edgegateway.egw.id

  pool_id = vcd_nsxt_alb_pool.ingress_http_pool.id

  service_engine_group_id = (
    data.vcd_nsxt_alb_edgegateway_service_engine_group.alb.service_engine_group_id
  )

  virtual_ip_address = cidrhost(
    var.os_config.vm_ip_cidr,
    tonumber(var.ip_plan.ingress_lb)
  )

  application_profile_type = "L4"

  service_port {
    start_port = 80
    type       = "TCP_PROXY"
  }
}

# -------------------------------------------------------------------------
# Kubernetes Ingress: HTTPS (порт 443 -> пул с портом 30443 и соседним IP)
# -------------------------------------------------------------------------

resource "vcd_nsxt_alb_pool" "ingress_https_pool" {
  org             = var.vcloud.orgname
  name            = "ingress-https-pool"
  edge_gateway_id = data.vcd_nsxt_edgegateway.egw.id

  algorithm    = "ROUND_ROBIN"
  default_port = 30443

  # Привязка системных мониторов
  health_monitor {
    name = "System-Ping"
  }
  health_monitor {
    name = "System-TCP"
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.w_node)
    )
    port = 30443
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.w_node) + 1
    )
    port = 30443
  }

  member {
    ip_address = cidrhost(
      var.os_config.vm_ip_cidr,
      tonumber(var.ip_plan.w_node) + 2
    )
    port = 30443
  }
}

resource "vcd_nsxt_alb_virtual_service" "ingress_https" {
  org             = var.vcloud.orgname
  name            = "ingress-https"
  edge_gateway_id = data.vcd_nsxt_edgegateway.egw.id

  pool_id = vcd_nsxt_alb_pool.ingress_https_pool.id

  service_engine_group_id = data.vcd_nsxt_alb_edgegateway_service_engine_group.alb.service_engine_group_id

  # Разносим на соседний IP (ingress_lb + 1), чтобы избежать конфликта в API балансировщика
  virtual_ip_address = cidrhost(
    var.os_config.vm_ip_cidr,
    tonumber(var.ip_plan.ingress_lb) + 1
  )

  application_profile_type = "L4"

  service_port {
    start_port  = 443
    type        = "TCP_PROXY"
  }
}
