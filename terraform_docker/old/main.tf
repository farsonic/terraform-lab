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
  endpoint = "https://10.9.23.63/api"
  password = "EfJCCiUkWQybuVHPPxTF67vX-dvCaC0l"
  username = ""
  insecure = true
}

resource "docker_network" "macvtap_network" {
  name   = "my_macvtap_net"
  driver = "macvlan"

  ipam_config {
    subnet = "10.29.21.0/24"
    gateway = "10.29.21.1"
  }

  options = {
    parent = "vlan.21"
    mode = "private"
  }
}

# Use Alpine as the base image
resource "docker_image" "alpine" {
  name = "alpine:latest"
}


data "phpipam_subnet" "subnet" {
  subnet_address = "10.29.21.0"
  subnet_mask    = 24
}

data "phpipam_first_free_address" "next_address" {
  subnet_id = data.phpipam_subnet.subnet.subnet_id
}

resource "phpipam_address" "newip" {
  subnet_id   = data.phpipam_subnet.subnet.subnet_id
  ip_address  = data.phpipam_first_free_address.next_address.ip_address
  hostname    = "tf-test-host.example.internal"
  description = "Managed by Terraform Docker script"

  lifecycle {
    ignore_changes = [
      subnet_id,
      ip_address,
    ]
  }
}

resource "docker_container" "containers" {
  count   = 1
  name    = "docker-container-${count.index + 1}"
  image   = docker_image.alpine.image_id
  restart = "always"

  # Keep the container running
  command = ["sleep", "infinity"]

  # Attach container to macvlan network with the IP address from PHPIPAM
  networks_advanced {
    name         = docker_network.macvtap_network.name
    ipv4_address = phpipam_address.newip.ip_address
  }
}

output "allocated_ip" { 
  value = phpipam_address.newip.ip_address
  description = "The Allocated IP Address from PHPIPAM"
}
