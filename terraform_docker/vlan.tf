resource "phpipam_section" "lab" {
  name        = "Lab"
  description = "Terraform test section"
}

resource "phpipam_vlan" "vlan_10" {
  name       = "VLAN 10"
  number     = 10
  description = "Terraform-managed VLAN 10"
}

resource "phpipam_subnet" "subnet_10" {
  subnet_address = "192.168.10.0"
  subnet_mask    = 24
  description    = "Terraform-managed subnet for VLAN 10"
  vlan_id        = phpipam_vlan.vlan_10.vlan_id 
  section_id     = phpipam_section.lab.section_id
}

resource "phpipam_address" "subnet_10_gateway_ip" {
  subnet_id   = phpipam_subnet.subnet_10.subnet_id
  ip_address  = "192.168.10.1"
  hostname    = "gateway"
  description = "Reserved gateway IP"
}