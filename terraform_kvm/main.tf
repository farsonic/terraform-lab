terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Number of VMs to be provisioned
variable "vm_count" {
  default = 3
}

# Isolated VLAN ID number, note there needs to be a corresponding defintion in the config directory
variable "vlan_id" {
  default = 21
}

# Base name for VMs
variable "vm_base_name" {
  default = "macvtap-vm-"
}


# Iterate through VM count
locals {
  vm_names = [for i in range(var.vm_count) : "${var.vm_base_name}${i + 1}"]
}

# Create storage pool for each VM
resource "libvirt_pool" "server_pool" {
  for_each = toset(local.vm_names)
  name     = "pool-${each.value}"
  type     = "dir"
  target {
    path = "/home/pensando/terraform_kvm/libvirt_pool/pool-${each.value}"
  }
}

# Create the base Ubuntu image
resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu.qcow2"
  pool   = libvirt_pool.server_pool[local.vm_names[0]].name
  source = "${path.module}/images/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# Create the VM disk using base volume
resource "libvirt_volume" "server_disk" {
  for_each       = toset(local.vm_names)
  name           = "disk-${each.value}.qcow2"
  size           = 10737418240 # 10GiB in bytes
  pool           = libvirt_pool.server_pool[each.value].name
  base_volume_id = libvirt_volume.ubuntu_base.id
}

# Generate Cloud-Init config per VM
resource "libvirt_cloudinit_disk" "commoninit" {
  for_each       = toset(local.vm_names)
  name           = "commoninit-${each.value}.iso"
  user_data      = templatefile("${path.module}/config/cloud_init.cfg", { hostname = each.value })
  network_config = file("${path.module}/config/network_config.cfg")
  pool           = libvirt_pool.server_pool[each.value].name
}

# Define each VM
resource "libvirt_domain" "vm" {
  for_each  = toset(local.vm_names)
  name      = each.value
  memory    = "1024"
  vcpu      = 4
  cloudinit = libvirt_cloudinit_disk.commoninit[each.value].id

  disk {
    volume_id = libvirt_volume.server_disk[each.value].id
    scsi = true
  }

  xml {
    xslt = file("config/vlan${var.vlan_id}.xsl")
  }
  
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}
