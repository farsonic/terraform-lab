output "docker_instances" {
  value = [
    for key, instance in phpipam_first_free_address.reserved_ips :
    format("Docker Instance:   %s  IP: %s  VLAN: %s",
      key,
      instance.ip_address,
      regex("Docker_(\\d+)_\\d+", key)[0]
    )
  ]
  description = "List of all Docker instances with IP and VLAN details."
}

output "incus_instances" {
  value = [
    for key, instance in incus_instance.incus_containers :
    format("Incus Instance: %s    IP: %s  MAC: %s  VLAN: %s",
      instance.name,
      try(regex("addresses:\\n      - ([0-9\\.]+)\\/24", try(instance.config["cloud-init.network-config"], ""))[0], "N/A"),
      try(instance.mac_address, "N/A"),
      try(regex("incus_vlan_(\\d+)_profile", try(instance.profiles[0], ""))[0], "N/A")
    )
  ]
  description = "List of all Incus instances with IP, MAC, and VLAN details."
}