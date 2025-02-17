terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
    phpipam = {
      source = "lord-kyron/phpipam"
    }
  }
}

provider "docker" {}

provider "phpipam" {
  app_id   = "terraform"
  endpoint = "https://192.168.0.106/api"
  password = "1Jr5dyhPu-Icw09-3g3TG00LwAhfGyi6	"
  username = ""
  insecure = true
}

# Variable to control the number of containers
variable "container_count" {
  default = 3
}

# Create Docker macvlan network
resource "docker_network" "macvtap_network" {
  name   = "my_macvtap_net"
  driver = "macvlan"

  ipam_config {
    subnet  = "10.29.21.0/24"
    gateway = "10.29.21.1"
  }

  options = {
    parent = "vlan.10"
    mode   = "private"
  }
}

# Use Alpine as the base image
resource "docker_image" "alpine" {
  name = "alpine:latest"
}

# Get PHPIPAM subnet details
data "phpipam_subnet" "subnet" {
  subnet_address = "192.168.10.0"
  subnet_mask    = 24
}

# *Fix: Request a unique IP address sequentially for each container*
resource "phpipam_address" "newip" {
  count      = var.container_count
  subnet_id  = data.phpipam_subnet.subnet.subnet_id
  hostname   = "docker-container-${count.index + 1}.example.internal"
  description = "Managed by Terraform Docker script"

  # *Fix: Manually request the next available free address*
  ip_address = element(
    flatten([for i in range(var.container_count) : data.phpipam_first_free_address.next_address[i].ip_address]), 
    count.index
  )

  lifecycle {
    ignore_changes = [
      subnet_id,
      ip_address,
    ]
  }
}

# *Ensure IP requests are made sequentially*
data "phpipam_first_free_address" "next_address" {
  count     = var.container_count
  subnet_id = data.phpipam_subnet.subnet.subnet_id
}

# Create multiple Docker containers with unique IPs from phpIPAM
resource "docker_container" "containers" {
  count   = var.container_count
  name    = "docker-container-${count.index + 1}"
  image   = docker_image.alpine.image_id
  restart = "always"

  # Keep the container running
  command = ["sleep", "infinity"]

  # Attach container to macvlan network with IP from phpIPAM
  networks_advanced {
    name         = docker_network.macvtap_network.name
    ipv4_address = phpipam_address.newip[count.index].ip_address
  }
}

# Output all allocated IPs
output "allocated_ips" {
  value       = [for ip in phpipam_address.newip : ip.ip_address]
  description = "The Allocated IP Addresses from PHPIPAM"
}
