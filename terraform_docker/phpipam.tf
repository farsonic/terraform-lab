# **Fetch subnet details dynamically per VLAN**
data "phpipam_subnet" "subnets" {
  for_each   = var.container_config
  depends_on = [phpipam_subnet.subnets]
  subnet_id  = phpipam_subnet.subnets[each.key].subnet_id
}

# **Fetch pre-allocated gateway IP per VLAN**
data "phpipam_address" "gateway_ips" {
  for_each   = var.container_config
  depends_on = [phpipam_address.gateway_ips]
  ip_address = phpipam_address.gateway_ips[each.key].ip_address
}