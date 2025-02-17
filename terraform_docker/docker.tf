variable "container_count" {
  default = 10
}

# Ensure VLAN & Subnet exist before reserving addresses
data "phpipam_subnet" "subnet_10" {
  subnet_address = "192.168.10.0"
  subnet_mask    = 24
  depends_on     = [phpipam_subnet.subnet_10]
}

# **Step 1: Fetch & Reserve Unique Free IPs from phpIPAM**
resource "phpipam_first_free_address" "reserved_ips" {
  count = var.container_count

  subnet_id   = phpipam_subnet.subnet_10.subnet_id
  hostname    = format("docker-container-%d", count.index + 1)
  description = "Managed by Terraform"
  depends_on  = [phpipam_subnet.subnet_10, phpipam_address.gateway_ip]
}

# **Step 2: Create Docker macvlan network**
resource "docker_network" "macvtap_network" {
  name   = "my_macvtap_net"
  driver = "macvlan"

  ipam_config {
    subnet  = "192.168.10.0/24"
    gateway = "192.168.10.1"
  }

  options = {
    parent = "vlan.10"
    mode   = "private"
  }
}

# **Step 3: Pull Alpine Image**
resource "docker_image" "alpine" {
  name = "alpine:latest"
}

# **Step 4: Ensure Each Container Gets a Unique IP**
resource "docker_container" "containers" {
  for_each = { for idx, ip in phpipam_first_free_address.reserved_ips : idx => ip }

  name    = format("docker-container-%d", each.key + 1)
  image   = docker_image.alpine.image_id
  restart = "always"
  command = ["sleep", "infinity"]

  # Attach container to macvlan network with reserved IP
  networks_advanced {
    name         = docker_network.macvtap_network.name
    ipv4_address = each.value.ip_address
  }

  depends_on = [phpipam_first_free_address.reserved_ips]
}

# **Step 5: Output Allocated IPs**
output "allocated_ips" {
  value       = [for ip in phpipam_first_free_address.reserved_ips : ip.ip_address]
  description = "The Allocated IP Addresses from PHPIPAM"
}