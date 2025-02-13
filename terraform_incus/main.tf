terraform {
  required_providers {
    incus = {
      source = "lxc/incus"
    }
  }
}

provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate = true
}

# Number of containers and VMs to be created
variable "container_count" {
  default = 3
}

variable "vm_count" {
  default = 0
}

# Create VLAN 21 profile
resource "incus_profile" "vlan21" {
  name = "vlan21_profile"

  device {
    name = "eth0"
    type = "nic"

    properties = {
      nictype = "macvlan"
      mode = "private"
      parent = "vlan.21"
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

# Create multiple Incus CONTAINERS using count
resource "incus_instance" "containers" {
  count            = var.container_count
  name             = "container${count.index + 1}"
  wait_for_network = false
  image            = "images:ubuntu/jammy"
  profiles         = [incus_profile.vlan21.name]
  type             = "container"
}

# Create multiple Incus VMs using count
resource "incus_instance" "vms" {
  count            = var.vm_count
  name             = "vm${count.index + 1}"
  wait_for_network = false
  image            = "images:ubuntu/focal"
  profiles         = [incus_profile.vlan21.name]
  type             = "virtual-machine"
  config = { 
    "security.secureboot" = "false"
  }
}
