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
  password = "1Jr5dyhPu-Icw09-3g3TG00LwAhfGyi6"
  username = ""
  insecure = true
}