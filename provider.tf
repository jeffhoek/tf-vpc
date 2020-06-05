variable "ibmcloud_api_key" {
  # default = "REPLACE_ME"
}

variable "region" {
  default = ""
}

variable "vpc_name" {
  type = string
  default = ""
}
variable "resource_group" {
  type = string
  default = ""
}
variable "security_group_rules" {
  type    = map
  default = {}
}
variable "acls" {
  type    = map
  default = {}
}
variable "routes" {
  type    = map
  default = {}
}
variable "address_prefixes" {
  type    = map
  default = {}
}
variable "public_gateway" {
  type    = list
  default = []
}
variable "subnets" {
  type    = map
  default = {}
}
variable "ssh_keys" {
  type = list
  default = []
}
variable "servers" {
  type = list
  default = []
}
variable "floating_ips" {
  type = list
  default = []
}
variable "cloud_init_data" {
  type    = map
  default = {}
}
variable "vpn_gateway" {
  type = map
  default = {}
}

variable "loadbalancers" {
  type = map
  default = {}
}


provider "ibm" {
  ibmcloud_api_key   = var.ibmcloud_api_key
  generation         = 2
  region             = var.region
}

module "vpc" {
  source = "./resources/tf12/vpc2"
  resource_group = var.resource_group
  vpc_name = var.vpc_name
  security_group_rules = var.security_group_rules
  acls = var.acls
  routes = var.routes
  address_prefixes = var.address_prefixes
  public_gateway = var.public_gateway
  subnets = var.subnets
  ssh_keys = var.ssh_keys
  servers = var.servers
  floating_ips = var.floating_ips
  cloud_init_data = var.cloud_init_data
  vpn_gateway = var.vpn_gateway
  loadbalancers = var.loadbalancers
}


output "vpc_id" {
  description = "The ID of the VPC"
  value = module.vpc.vpc_id
}

output "vpn_public_ip" {
  description = "VPN Public IP Address"
  value = module.vpc.vpn_gw_ip
}

#output "instances" {
#  value = module.vpc.instances
#}
