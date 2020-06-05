variable "resource_group" {
  description = "The resource group ID where the VPC to be created"
  type        = string
  default     = ""
}


variable "vpc_name" {
  description = "The resource group ID where the VPC to be created"
  type        = string
  default     = "The name of the VPC"
}

variable "security_group_rules" {
  description = "Network rules that establish filtering to each network interface of a virtual server instance"
  type = map
  default = {}
}

variable "acls" {
  description = "Access Control List that establish inbound/outbound rules on the subnet"
  type = map
  default = {}
}

variable "routes" {
  description = "Allows you to specify the next hop for packets based on their destination address"
  type = map
  default = {}
}

variable "address_prefixes" {
  description = "IP range that will be defined for the VPC for a certain location"
  type = map
  default = {}
}

variable "public_gateway" {
  description = "Allow all attached resources to communicate with the public Internet"
  type = list
  default = []
}

variable "subnets" {
  description = "IP range in CIDR notation from the address prefix"
  type = map
  default = {}
}

variable "ssh_keys" {
  description = "A list of SSH keys that will be utilized by the instances"
  type = list
  default = []
}

variable "cloud_init_data" {
  description = "Optional user data that automatically performs common configuration tasks or runs scripts"
  type = map
  default = {}
}

variable "servers" {
  description = "A list of server that you wish to define within your VPC"
  type = list
  default = []
}

variable "floating_ips" {
  description = "A list of server names that you wish to define a floating IP to which will allow access to it from the public Internet"
  type = list
  default = []
}

variable "vpn_gateway" {
  description = "Map defining the information needed to create a VPN service to securely connect your VPC to another private network"
  type = map
  default = {}
}

variable "loadbalancers" {
  description = "Map defining the information needed to create one or more loadbalancer service"
  type = map
  default = {}
}
