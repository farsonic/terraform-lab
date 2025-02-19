terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
    incus = {
      source = "lxc/incus"
    }
    phpipam = {
      source = "lord-kyron/phpipam"
      version = "1.6.2"
    }
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

provider "docker" {}

provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = true
}

provider "phpipam" {
  app_id   = "terraform"
  endpoint = "https://192.168.0.106/api"
  password = "1Jr5dyhPu-Icw09-3g3TG00LwAhfGyi6"
  username = ""
  insecure = true
}

provider "libvirt" {
  uri = "qemu:///system" # Connect to the local KVM hypervisor
}