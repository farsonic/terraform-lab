resource "docker_network" "macvtap_networks" {
  for_each = var.container_config

  name   = format("my_macvtap_net_%s", each.key)
  driver = "macvlan"

  ipam_config {
    subnet  = format("%s/%d", phpipam_subnet.subnets[each.key].subnet_address, phpipam_subnet.subnets[each.key].subnet_mask)
    gateway = phpipam_address.gateway_ips[each.key].ip_address
  }

  options = {
    parent       = format("vlan.%s", replace(each.key, "vlan_", ""))
    macvlan_mode = "private"
  }
}