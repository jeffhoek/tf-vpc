output "vpc_id" {
  description = "The ID of the VPC"
  value       = concat(ibm_is_vpc.vpc.*.id, [""])[0]
}

output vpn_gw_ip {
  description = "VPN Public IP Address"
  value       = try(
    ibm_is_vpn_gateway.vpn_gw[keys(var.vpn_gateway)[0]].public_ip_address,
    ""
  )
}

locals {
  server_instances = flatten([
    for instance in ibm_is_instance.server-instances : [
      merge({"id": instance["id"]})
    ]]
  )
}

#output "instances" {
#  description = "Information about VPN server instances"
#  value       = ibm_is_instance.server-instances
#}
