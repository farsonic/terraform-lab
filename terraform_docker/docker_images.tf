# **Pull Alpine Image**
resource "docker_image" "alpine" {
  name = "alpine:latest"
}