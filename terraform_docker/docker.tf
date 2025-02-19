variable "container_config" {
  type = map(number)
  default = {
    "vlan_10" = 5 
    "vlan_20" = 5
  }
}

locals {
  container_instances = flatten([
    for vlan, count in var.container_config : [
      for i in range(count) : {
        vlan   = vlan
        number = i + 1
      }
    ]
  ])
}







# ------------- Change nothing below this -----------------
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

# **Request unique free IPs for containers per VLAN**
resource "phpipam_first_free_address" "reserved_ips" {
  for_each = { for instance in local.container_instances : "${instance.vlan}-${instance.number}" => instance }

  subnet_id   = phpipam_subnet.subnets[each.value.vlan].subnet_id
  hostname    = format("docker-container-%s-%d", each.value.vlan, each.value.number)
  description = "Managed by Terraform"
  depends_on  = [phpipam_subnet.subnets, phpipam_address.gateway_ips]
}

# **Create a lookup map to track which container got which IP**
locals {
  container_ip_map = {
    for key, ip in phpipam_first_free_address.reserved_ips :
    key => merge(ip, { vlan = regex("^(.*)-", key)[0], number = regex("-(\\d+)$", key)[0] })
  }
}

# **Dynamically create the Docker macvlan network per VLAN**
resource "docker_network" "macvtap_networks" {
  for_each = var.container_config

  name   = format("my_macvtap_net_%s", each.key)
  driver = "macvlan"

  ipam_config {
    subnet  = format("%s/%d", phpipam_subnet.subnets[each.key].subnet_address, phpipam_subnet.subnets[each.key].subnet_mask)
    gateway = phpipam_address.gateway_ips[each.key].ip_address
  }

  options = {
    parent = format("vlan.%s", replace(each.key, "vlan_", ""))  # Extract VLAN ID dynamically
    #macvlan_mode must equal private for this to isolate containers. 
    macvlan_mode   = "private"
  }
}

# **Pull Alpine Image**
resource "docker_image" "alpine" {
  name = "alpine:latest"
}

# **Create Docker Containers with Unique IPs per VLAN**
resource "docker_container" "containers" {
  for_each = local.container_ip_map

  name    = format("docker-container-%s-%s", each.value.vlan, each.value.number)
  image   = docker_image.alpine.image_id
  restart = "always"
  command = ["sleep", "infinity"]
  network_mode = "bridge"

  # Attach container to the corresponding VLAN's macvlan network
  networks_advanced {
    name         = docker_network.macvtap_networks[each.value.vlan].name
    ipv4_address = each.value.ip_address
  }
}

# **Outputs**
output "allocated_ips" {
  value       = { for key, ip in phpipam_first_free_address.reserved_ips : key => ip.ip_address }
  description = "The Allocated IP Addresses from PHPIPAM"
}

output "gateway_ips" {
  value       = { for key, ip in phpipam_address.gateway_ips : key => ip.ip_address }
  description = "The Allocated Gateway IPs from PHPIPAM"
}

output "subnet_info" {
  value       = { for key, subnet in phpipam_subnet.subnets : key => format("%s/%d", subnet.subnet_address, subnet.subnet_mask) }
  description = "The Allocated Subnets and Masks from PHPIPAM"
}