variable "container_config2" {
  type = map(number)
  default = {
    "vlan_10" = 4
    "vlan_20" = 4
  }
}

locals {
  container_instances2 = flatten([
    for vlan, count in var.container_config2 : [
      for i in range(count) : {
        vlan   = vlan
        number = i + 1
      }
    ]
  ])
}

# ------------- Change nothing below this -----------------

# **Request unique free IPs for containers per VLAN**
resource "phpipam_first_free_address" "reserved_ips2" {
  for_each = { for instance in local.container_instances2 :
    format("Incus_%s_%d", replace(instance.vlan, "vlan_", ""), instance.number) => instance
  }

  subnet_id   = phpipam_subnet.subnets[each.value.vlan].subnet_id
  hostname    = format("incus-cnt-%s-%d", each.value.vlan, each.value.number)
  description = "Managed by Terraform"
  depends_on  = [phpipam_subnet.subnets, phpipam_address.gateway_ips]
}

locals {
  container_ip_map2 = {
    for key, ip in phpipam_first_free_address.reserved_ips2 :
    key => merge(ip, {
      vlan   = "vlan_${regex("Incus_(\\d+)_", key)[0]}",  # Extract VLAN number and format it correctly
      number = regex("Incus_\\d+_(\\d+)", key)[0]         # Extract container number
    })
  }
}

resource "incus_profile" "incus_vlan_profiles" {
  for_each = var.container_config2  # Create a profile for each VLAN

  name = format("incus_vlan_%s_profile", replace(each.key, "vlan_", ""))  # Unique profile name per VLAN

  device {
    name = "eth0"
    type = "nic"
    properties = {
      nictype = "macvlan"
      mode    = "private"
      parent  = format("vlan.%s", replace(each.key, "vlan_", ""))  # Extract VLAN number
    }
  }
  device {
    type = "disk"
    name = "root"
    properties = {
      pool = "default"
      path = "/"
    }
  }
}

resource "incus_instance" "incus_containers" {
  for_each = local.container_ip_map2

  name             = format("IncusContainer%s%s", replace(each.value.vlan, "vlan_", ""), each.value.number)
  image            = "images:debian/12/cloud"
  wait_for_network = false
  profiles         = [incus_profile.incus_vlan_profiles[each.value.vlan].name]
  type             = "container"
  config = {
    "boot.autostart" = true
    "cloud-init.network-config" = <<-EOT
    #cloud-config
    version: 2
    ethernets:
      eth0:
        dhcp4: false
        dhcp6: false
        addresses:
          - ${each.value.ip_address}/24
        gateway4: ${phpipam_address.gateway_ips[each.value.vlan].ip_address}
    EOT
    "cloud-init.user-data" = <<-EOT
    #cloud-config
    timezone: Australia/Brisbane
    package_update: true
    package_upgrade: true
    packages:
      - openssh-server
      - sudo
    EOT
  }
}
