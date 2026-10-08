# ---------- Что уже есть в облаке ----------
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
    lesson = "12"
  }
}

# ---------- Группы безопасности: кто к кому может ходить ----------
#
#   интернет ──80──▶ балансировщик ──8000──▶ app-1..N ──5432/6379──▶ db
#
# Серверы приложения: порт 8000 открыт ТОЛЬКО для балансировщика.
resource "sbercloud_networking_secgroup" "app" {
  name = "${var.prefix}-app-sg"
}

# Общий (shared) балансировщик cloud.ru ходит к серверам и делает health check
# с адресов служебной сети 100.125.0.0/16. Без этого правила все серверы будут «unhealthy».
resource "sbercloud_networking_secgroup_rule" "app_from_lb" {
  security_group_id = sbercloud_networking_secgroup.app.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8000
  port_range_max    = 8000
  remote_ip_prefix  = "100.125.0.0/16"
}

# База: PostgreSQL и Redis открыты ТОЛЬКО для серверов из группы app.
# remote_group_id вместо IP: добавим app-3 — доступ появится у него автоматически.
resource "sbercloud_networking_secgroup" "db" {
  name = "${var.prefix}-db-sg"
}

resource "sbercloud_networking_secgroup_rule" "db_from_app" {
  for_each = toset(["5432", "6379"])

  security_group_id = sbercloud_networking_secgroup.db.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = tonumber(each.value)
  port_range_max    = tonumber(each.value)
  remote_group_id   = sbercloud_networking_secgroup.app.id
}

# Только для отладки (debug_public_ips = true): SSH отовсюду
resource "sbercloud_networking_secgroup_rule" "debug_ssh" {
  for_each = var.debug_public_ips ? {
    app = sbercloud_networking_secgroup.app.id
    db  = sbercloud_networking_secgroup.db.id
  } : {}

  security_group_id = each.value
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}
