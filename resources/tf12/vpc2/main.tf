#---------------------------------------------------------
# Get resource_group id
#---------------------------------------------------------

data "ibm_resource_group" "group" {
  name = var.resource_group
}

#---------------------------------------------------------
# Create new VPC
#---------------------------------------------------------
resource "ibm_is_vpc" "vpc" {
  name                = var.vpc_name
  resource_group      = data.ibm_resource_group.group.id
}

##########################################################
# Network resources
##########################################################
locals {
  security_groups = distinct(flatten([
    [for k, v in var.security_group_rules : v["security_group"] if v["security_group"] != "default"]
  ]))
}

#---------------------------------------------------------
# Create security group resources
#---------------------------------------------------------
resource ibm_is_security_group "vpc_sg" {
  for_each = toset(local.security_groups)
  name = each.key
  vpc = ibm_is_vpc.vpc.id
  resource_group = data.ibm_resource_group.group.id
}

#---------------------------------------------------------
# Create security group rules resources
#---------------------------------------------------------
resource "ibm_is_security_group_rule" "sg_rules" {
  for_each  = var.security_group_rules
  group     = each.value["security_group"] == "default" ? ibm_is_vpc.vpc.default_security_group : ibm_is_security_group.vpc_sg[each.value["security_group"]].id
  direction = each.value["direction"]
  remote    = each.value["remote"]
  ip_version = each.value["ip_version"] != "" ? each.value["ip_version"] : "ipv4"
  dynamic "icmp" {
    for_each = lookup(each.value, "icmp", [])
    content {
      code = icmp.value["code"]
      type = icmp.value["type"]
    }
  }
  dynamic "tcp" {
    for_each = lookup(each.value, "tcp", [])
    content {
      port_min = tcp.value["port_min"]
      port_max = tcp.value["port_max"]
    }
  }
  dynamic "udp" {
    for_each = lookup(each.value, "udp", [])
    content {
      port_min = udp.value["port_min"]
      port_max = udp.value["port_max"]
    }
  }
}

#---------------------------------------------------------
# Create ACL resources
#---------------------------------------------------------
resource "ibm_is_network_acl" "acls" {
  for_each  = var.acls
  name      = each.key
  vpc       = ibm_is_vpc.vpc.id
  dynamic "rules" {
    for_each = each.value["rules"]
    content {
      name   = rules.value["name"]
      action = rules.value["action"]
      source = rules.value["source"]
      destination = rules.value["destination"]
      direction   = rules.value["direction"]
      dynamic "icmp" {
        for_each = lookup(rules.value, "icmp", [])
        content {
          code = icmp.value["code"]
          type = icmp.value["type"]
        }
      }
      dynamic "tcp" {
        for_each = lookup(rules.value, "tcp",[])
        content {
          port_max = tcp.value["port_max"]
          port_min = tcp.value["port_min"]
          source_port_max = tcp.value["source_port_max"]
          source_port_min = tcp.value["source_port_min"]
        }
      }
      dynamic "udp" {
        for_each = lookup(rules.value, "udp", [])
        content {
          port_max = udp.value["port_max"]
          port_min = udp.value["port_min"]
          source_port_max = udp.value["source_port_max"]
          source_port_min = udp.value["source_port_min"]
        }
      }
    }
  }
}

#---------------------------------------------------------
# Create address prefixes resources
#---------------------------------------------------------
resource "ibm_is_vpc_address_prefix" "address_prefixes" {
  for_each = var.address_prefixes
  name =  each.key
  vpc  = ibm_is_vpc.vpc.id
  zone = each.value["zone_name"]
  cidr = each.value["cidr"]
}

#---------------------------------------------------------
# Create public gateway resources
#---------------------------------------------------------
resource "ibm_is_public_gateway" "public_gateway" {
  for_each = toset(var.public_gateway)
  name = "${var.vpc_name}-${each.key}-pubgw"
  vpc  = ibm_is_vpc.vpc.id
  zone = each.key
  timeouts {
     create = "60m"
     delete = "60m"
  }
}

#---------------------------------------------------------
# ibm_is_subnet: Create subnet resources
#---------------------------------------------------------
resource "ibm_is_subnet" "subnets" {
  for_each        = var.subnets
  name            = each.key
  vpc             = ibm_is_vpc.vpc.id
  zone            = each.value["zone"]
  ipv4_cidr_block = each.value["cidr_block"]
  public_gateway  = each.value["public_gateway"] != "" ? ibm_is_public_gateway.public_gateway[each.value["public_gateway"]].id : ""
  network_acl     = lookup(each.value, "network_acl", "") != "" ? ibm_is_network_acl.acls[each.value["network_acl"]].id : ibm_is_vpc.vpc.default_network_acl

  timeouts {
    create = "90m"
    delete = "30m"
  }

  resource_group = data.ibm_resource_group.group.id

  depends_on = [ibm_is_vpc_address_prefix.address_prefixes]
}

#---------------------------------------------------------
# ibm_is_vpc_route: Create vpc route resource
#---------------------------------------------------------
resource "ibm_is_vpc_route" "route" {
  for_each    = var.routes
  name        = each.key
  vpc         = ibm_is_vpc.vpc.id
  zone        = each.value["zone"]
  destination = each.value["destination"]
  next_hop    = each.value["next_hop"]
}


##########################################################
# Compute resources
##########################################################
locals {
  serverList = flatten([
    for server in var.servers : [
      for i in range(server["count"]) : merge({serverIndex = i}, server)
    ]
  ])
  serverMap = {
    for k, v in tolist(local.serverList) :
      "${v.name}-${v.serverIndex}" => v
  }
  volumeList = flatten([
    for server in var.servers: [
      for serverIndex in range(server.count): [
        for volume in server.volumes: [
          merge({name: "${volume["prefix"]}-${serverIndex}"}, volume)
        ]
      ]
    ]
  ])
  volumeMap = {
    for k, v in tolist(local.volumeList) :
      v.name => v
  }
}

#---------------------------------------------------------
# SSH Keys
#---------------------------------------------------------
locals {
   ssh_keys_to_upload = {
     for sshkey in var.ssh_keys :
       sshkey.name => {public_key: sshkey.public_key, resource_group: lookup(sshkey, "resource_group", ""), tags: lookup(sshkey, "tags", "")}
       if lookup(sshkey,"public_key", "") != ""
   }
   ssh_keys = [ for sshkey in var.ssh_keys : sshkey.name ]
}

resource "ibm_is_ssh_key" "sshkeys_to_upload" {
  for_each       = local.ssh_keys_to_upload
  name           = each.key
  public_key     = each.value["public_key"]
  resource_group = data.ibm_resource_group.group.id
  tags           = split(",", each.value["tags"])
}

data "ibm_is_ssh_key" "sshkey" {
  for_each = toset(local.ssh_keys)
  name = each.key

  depends_on = [ibm_is_ssh_key.sshkeys_to_upload]
}

#---------------------------------------------------------
# Create cloud-init user data
#---------------------------------------------------------
data "template_cloudinit_config" "cloud-init" {
   for_each = var.cloud_init_data
   base64_encode = each.value["base64_encode"]
   gzip = each.value["gzip"]
   part {
     content = each.value["content"]
   }
}

#---------------------------------------------------------
# Create data volumes
#---------------------------------------------------------
resource "ibm_is_volume" "volumes" {
  for_each = local.volumeMap
  name = each.key
  profile = each.value["profile"]
  zone = each.value["zone"]
  capacity = each.value["capacity"]
}

#---------------------------------------------------------
# Create instances
#---------------------------------------------------------
resource "ibm_is_instance" "server-instances" {
  for_each = local.serverMap
  name     = each.key
  zone     = each.value["zone"]
  profile  = each.value["profile"]
  image    = each.value["image"]
  vpc       = ibm_is_vpc.vpc.id
  keys      = [for key in each.value["ssh_key_list"] : data.ibm_is_ssh_key.sshkey[key].id]
  volumes = [for v in each.value["volumes"] : ibm_is_volume.volumes["${v.prefix}-${each.value["serverIndex"]}"].id]

  primary_network_interface {
    subnet = ibm_is_subnet.subnets[each.value["subnet"]].id
    security_groups = length(lookup(each.value, "security_groups", [])) == 0 ? [ibm_is_vpc.vpc.default_security_group] : [for sg in each.value["security_groups"] : sg == "default" ? ibm_is_vpc.vpc.default_security_group : ibm_is_security_group.vpc_sg[sg].id]
  }

  dynamic "network_interfaces" {
    for_each = each.value["network_interfaces"]
    content {
      name = network_interfaces.key
      subnet = ibm_is_subnet.subnets[network_interfaces.value["subnet"]].id
      security_groups = length(lookup(each.value, "security_groups", [])) == 0 ? [ibm_is_vpc.vpc.default_security_group] : [for sg in network_interfaces.value["security_groups"] : sg == "default" ? ibm_is_vpc.vpc.default_security_group : ibm_is_security_group.vpc_sg[sg].id]
    }
  }

  user_data = each.value["user_data"] != "" ? data.template_cloudinit_config.cloud-init[each.value["user_data"]].rendered : ""

  resource_group = data.ibm_resource_group.group.id

  timeouts {
    create = "90m"
    delete = "30m"
  }
}

#---------------------------------------------------------
# Create floating IPs
#---------------------------------------------------------
resource "ibm_is_floating_ip" "floating-ips" {
  count  =  length(var.floating_ips)
  name   = "${var.floating_ips[count.index]}-fip"
  target = ibm_is_instance.server-instances[var.floating_ips[count.index]].primary_network_interface[0].id
}

##########################################################
# VPN resources
##########################################################
locals {
  vpn_gateway_connection_list = flatten([
    for k, v in var.vpn_gateway : [
      for kc, kv in v["connection"] : [
         merge({vpn_gw: k}, {name: kc}, kv)
      ]
    ]
  ])

  vpn_gateway_connection_map = {
    for k, v in tolist(local.vpn_gateway_connection_list) :
      v.name => v
  }
}

#---------------------------------------------------------
# Create VPN Gateway resources
#---------------------------------------------------------
resource "ibm_is_vpn_gateway" "vpn_gw" {
  for_each = var.vpn_gateway
  name   = each.key
  subnet = ibm_is_subnet.subnets[each.value["subnet"]].id
  resource_group = data.ibm_resource_group.group.id
}

#---------------------------------------------------------
# Create VPN Gateway Connection resources
#---------------------------------------------------------
resource "ibm_is_vpn_gateway_connection" "vpn_gateway_connection" {
  for_each      = local.vpn_gateway_connection_map
  name          = each.key
  vpn_gateway   = ibm_is_vpn_gateway.vpn_gw[each.value["vpn_gw"]].id
  peer_address  = each.value["peer_address"]
  preshared_key = each.value["preshared_key"]
  local_cidrs    = [ for lc in each.value["local_cidrs"] : ibm_is_subnet.subnets[lc].ipv4_cidr_block ]
  peer_cidrs    = each.value["peer_cidrs"]
  admin_state_up = each.value["admin_state_up"]
}

##########################################################
# Load Balance resources
##########################################################
locals {
  lbpool_list = flatten([
    for lb_k, lb_v in var.loadbalancers : [
      for pool in lb_v["pools"] : [
        merge(pool, {lb_name: lb_k})
      ]
    ]
  ])

  lbpool_map = {
    for k, v in local.lbpool_list :
      v["name"] => v
  }

  lbpool_members_list = flatten([
    for lb_k, lb_v in var.loadbalancers : [
      for pool in lb_v["pools"] : [
        for member in pool["members"] : [
          merge(member, {lb_name: lb_k, lb_pool: pool["name"]})
        ]
      ]
    ]
  ])

  lbpool_members = {
    for member in local.lbpool_members_list :
      member.address => member
  }

  lblistener_list = flatten([
    for lb_k, lb_v in var.loadbalancers : [
      for listener in lb_v["listeners"] : [
        merge(listener, {lb_name: lb_k})
      ]
    ]
  ])

  lblistener_map = {
    for k, v in local.lblistener_list :
      v["port"] => v
  }
}

resource "ibm_is_lb" "lbs" {
  for_each = var.loadbalancers
  name     = each.key
  subnets  = [ for subnet in each.value["subnets"] : ibm_is_subnet.subnets[subnet].id ]
  type     = lookup(each.value, "type", "public")
  resource_group = data.ibm_resource_group.group.id
  tags           = lookup(each.value, "tags", "") != "" ? split(",", lookup(each.value, "tags", "")): []
}

resource "ibm_is_lb_pool" "lb_pools" {
  for_each       = local.lbpool_map
  name           = each.key
  lb             = ibm_is_lb.lbs[each.value["lb_name"]].id
  algorithm      = each.value["algorithm"]
  protocol       = each.value["protocol"]
  health_delay   = each.value["health_delay"]
  health_retries = each.value["health_retries"]
  health_timeout = each.value["health_timeout"]
  health_type    = each.value["health_type"]
  health_monitor_url = lookup(each.value, "health_monitor_url", "")
  health_monitor_port = lookup(each.value, "health_monitor_port", null)
  session_persistence_type = lookup(each.value, "session_persistence_type", null)
  session_persistence_cookie_name = lookup(each.value, "session_persistence_cookie_name", null)
}


resource "ibm_is_lb_pool_member" "lb_members" {
  for_each       = local.lbpool_members
  lb             = ibm_is_lb.lbs[each.value["lb_name"]].id
  pool           = ibm_is_lb_pool.lb_pools[each.value["lb_pool"]].id
  port           = each.value["port"]
  target_address = each.value["address"]
  weight         = lookup(each.value, "weight", null)
}

resource "ibm_is_lb_listener" "lb_listener" {
  for_each = local.lblistener_map
  lb       = ibm_is_lb.lbs[each.value["lb_name"]].id
  port     = each.value["port"]
  protocol = each.value["protocol"]
  default_pool = ibm_is_lb_pool.lb_pools[each.value["pool"]].id
  certificate_instance = lookup(each.value, "certificate_instance", null)
  connection_limit = lookup(each.value, "connection_limit", null)
}
