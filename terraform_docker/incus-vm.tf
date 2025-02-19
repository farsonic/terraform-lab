variable "vm_config" {
  type = map(number)
  default = {
    "vlan_10" = 1
    "vlan_20" = 1
  }
}

locals {
  vm_instances = flatten([
    for vlan, count in var.vm_config : [
      for i in range(count) : {
        vlan   = vlan
        number = i + 1
      }
    ]
  ])
}

# **Request unique free IPs for VMs per VLAN**
resource "phpipam_first_free_address" "reserved_ips_vm" {
  for_each = { for instance in local.vm_instances :
    format("IncusVM_%s_%d", replace(instance.vlan, "vlan_", ""), instance.number) => instance
  }

  subnet_id   = phpipam_subnet.subnets[each.value.vlan].subnet_id
  hostname    = format("incus-vm-%s-%d", each.value.vlan, each.value.number)
  description = "Managed by Terraform"
  depends_on  = [phpipam_subnet.subnets, phpipam_address.gateway_ips]
}

locals {
  vm_ip_map = {
    for key, ip in phpipam_first_free_address.reserved_ips_vm :
    key => merge(ip, {
      vlan   = "vlan_${regex("IncusVM_(\\d+)_", key)[0]}",  # Extract VLAN number and format correctly
      number = regex("IncusVM_\\d+_(\\d+)", key)[0]         # Extract VM number
    })
  }
}

# **Create Incus Profiles for VMs (One Per VLAN)**
resource "incus_profile" "incus_vm_profiles" {
  for_each = var.vm_config  # Create a profile for each VLAN

  name = format("incus_vm_%s_profile", replace(each.key, "vlan_", ""))  # Unique profile name per VLAN

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

# **Create Incus Virtual Machines with phpIPAM Assigned IPs**
resource "incus_instance" "incus_vms" {
  for_each = local.vm_ip_map

  name             = format("IncusVM-%s%s", replace(each.value.vlan, "vlan_", ""), each.value.number)
  image            = "images:debian/12/cloud"
  wait_for_network = false
  profiles         = [incus_profile.incus_vm_profiles[each.value.vlan].name]
  type             = "virtual-machine"

  config = {
    "boot.autostart" = true
    "limits.cpu"     = "2"
    "limits.memory"  = "2GB"
    "cloud-init.network-config" = <<-EOT
    version: 2
    ethernets:
      enp5s0:
        dhcp4: false
        dhcp6: false
        addresses:
          - ${each.value.ip_address}/24
        gateway4: ${phpipam_address.gateway_ips[each.value.vlan].ip_address}
    EOT
    "cloud-init.user-data" = <<-EOT
    #cloud-config
    timezone: UTC
    package_update: true
    package_upgrade: true
    packages:
      - openssh-server
      - sudo
    EOT
  }
}

# **Outputs**
output "allocated_ips_vm" {
  value = {
    for key, ip in phpipam_first_free_address.reserved_ips_vm :
    replace(key, "-", "_") => ip.ip_address
  }
  description = "The Allocated IP Addresses from PHPIPAM for Incus VMs"
}

output "gateway_ips_vm" {
  value = {
    for key, ip in phpipam_address.gateway_ips :
    "incus-vm-${key}" => ip.ip_address
  }
  description = "The Allocated Gateway IPs from PHPIPAM for Incus VMs"
}

output "subnet_info_vm" {
  value = {
    for key, subnet in phpipam_subnet.subnets :
    "incus-vm-${key}" => format("%s/%d", subnet.subnet_address, subnet.subnet_mask)
  }
  description = "The Allocated Subnets and Masks from PHPIPAM for Incus VMs"
}