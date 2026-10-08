# ---------- Общее для всех серверов: читаем облако ----------
data "sbercloud_availability_zones" "zones" {}

data "sbercloud_images_image" "ubuntu" {
  name_regex  = var.image_name_regex
  visibility  = "public"
  most_recent = true
}

data "sbercloud_vpc_subnet" "course" {
  name = var.subnet_name
}

locals {
  zone = data.sbercloud_availability_zones.zones.names[0]
  tags = {
    course = "hse-devops"
    owner  = var.prefix
    lesson = "11"
  }
}

# ---------- Общее для всех серверов: создаём один раз ----------
resource "sbercloud_networking_secgroup" "web" {
  name = "${var.prefix}-web-sg"
}

resource "sbercloud_networking_secgroup_rule" "ssh" {
  security_group_id = sbercloud_networking_secgroup.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_ssh_cidr
}

resource "sbercloud_networking_secgroup_rule" "http" {
  security_group_id = sbercloud_networking_secgroup.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-l11-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ---------- Серверы: один модуль, столько копий, сколько строк в var.servers ----------
module "web" {
  source   = "../modules/vm"
  for_each = var.servers

  name               = "${var.prefix}-${each.key}"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor             = var.vm_flavor
  availability_zone  = local.zone
  subnet_id          = data.sbercloud_vpc_subnet.course.id
  security_group_ids = [sbercloud_networking_secgroup.web.id]
  key_pair           = sbercloud_kps_keypair.key.name
  disk_size          = max(each.value.disk_size, data.sbercloud_images_image.ubuntu.min_disk_gb)
  tags               = local.tags

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    name = "${var.prefix}-${each.key}"
  })
}
