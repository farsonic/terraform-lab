variable "vlans" {
  type = map(object({
    vlan_number  = number
    subnet       = string
    subnet_mask  = number
    gateway_ip   = string
  }))

  default = {
    "vlan_10" = {
      vlan_number = 10
      subnet      = "192.168.10.0"
      subnet_mask = 24
      gateway_ip  = "192.168.10.1"
    }
    "vlan_20" = {
      vlan_number = 20
      subnet      = "192.168.20.0"
      subnet_mask = 24
      gateway_ip  = "192.168.20.1"
    }
  }
}


# ------------- Change nothing below this -----------------
# Create a Lab section where VLANs and Subnets are attached 
resource "phpipam_section" "lab" {
  name        = "Lab"
  description = "Terraform Lab"
}

resource "phpipam_vlan" "vlans" {
  for_each    = var.vlans
  name        = "VLAN ${each.value.vlan_number}"
  number      = each.value.vlan_number
  description = "VLAN ${each.value.vlan_number}"
}

resource "phpipam_subnet" "subnets" {
  for_each       = var.vlans
  subnet_address = each.value.subnet
  subnet_mask    = each.value.subnet_mask
  description    = "Terraform-managed subnet for VLAN ${each.value.vlan_number}"
  vlan_id        = phpipam_vlan.vlans[each.key].vlan_id
  section_id     = phpipam_section.lab.section_id
}

resource "phpipam_address" "gateway_ips" {
  for_each    = var.vlans
  subnet_id   = phpipam_subnet.subnets[each.key].subnet_id
  ip_address  = each.value.gateway_ip
  hostname    = "gateway-${each.value.vlan_number}"
  description = "Reserved gateway IP for VLAN ${each.value.vlan_number}"
}