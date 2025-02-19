variable "kvm_config" {
  type = map(number)
  default = {
    "vlan_10" = 2
    "vlan_20" = 2
  }
}

locals {
  kvm_instances = flatten([
    for vlan, count in var.kvm_config : [
      for i in range(count) : {
        vlan   = vlan
        number = i + 1
      }
    ]
  ])
}


# ------------- Change nothing below this -----------------

# -------- Create a map of IP Addresses for KVM -----------

resource "phpipam_first_free_address" "reserved_ips_kvm" {
  for_each = { for instance in local.kvm_instances :
    format("KVM_%s_%d", replace(instance.vlan, "vlan_", ""), instance.number) => instance
  }
  subnet_id   = phpipam_subnet.subnets[each.value.vlan].subnet_id
  hostname    = format("KVM-VM-%s-%d", each.value.vlan, each.value.number)
  description = "Managed by Terraform"
  depends_on  = [phpipam_subnet.subnets, phpipam_address.gateway_ips]
}


locals {
  kvm_ip_map = {
    for key, ip in phpipam_first_free_address.reserved_ips_kvm :
    key => merge(ip, {
      vlan   = "vlan_${regex("KVM_(\\d+)_", key)[0]}",    # Extract VLAN number and format it correctly
      number = regex("KVM_\\d+_(\\d+)", key)[0]           # Extract container number
    })
  }
}


# --------- Interate to create the KVM instances ------------



#Create the default storage pool 
resource "libvirt_pool" "server_pool" {
  name     = "default"
  type     = "dir"
  target {
    path = "/home/pensando/terraform_kvm/libvirt_pool/"
  }
}


# Create a base Ubuntu image for each VM 
resource "libvirt_volume" "ubuntu_base" {
  for_each = local.kvm_ip_map
  name   = "ubuntu-${each.key}.qcow2"
  pool   = libvirt_pool.server_pool.name
  source = "${path.module}/images/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# Create the VM disk using base volume
resource "libvirt_volume" "server_disk" {
  for_each       = local.kvm_ip_map
  name           = "disk-${each.key}.qcow2"
  size           = 10737418240  # 10GiB in bytes
  pool           = libvirt_pool.server_pool[each.value.vlan].name
  base_volume_id = libvirt_volume.ubuntu_base[each.key].id
}

# Generate Cloud-Init config per VM
resource "libvirt_cloudinit_disk" "commoninit" {
  for_each       = local.kvm_ip_map
  name           = "commoninit-${each.key}.iso"
  user_data      = templatefile("${path.module}/kvm/config/cloud_init.cfg", { hostname = each.key })
  network_config = file("${path.module}/kvm/config/network_config.cfg")
  pool           = "default"
}


resource "libvirt_domain" "vm" {
  for_each       = local.kvm_ip_map
  name           = each.value
  memory         = "1024"
  vcpu           = 2
  cloudinit      = libvirt_cloudinit_disk.commoninit[each.key].id

  disk {
    volume_id = libvirt_volume.server_disk[each.value].id
    scsi = true
  }
  xml {
    xslt = file("kvm/config/vlan${var.vlan_id}.xsl")
  }
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}