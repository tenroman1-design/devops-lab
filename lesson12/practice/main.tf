resource "sbercloud_kps_keypair" "key" {
  name       = "${var.prefix}-l12-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ---------- База данных: одна ВМ, без публичного IP ----------
module "db" {
  source = "../../lesson11/modules/vm" # тот же модуль, что в занятии 11

  name               = "${var.prefix}-db"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor             = var.vm_flavor
  availability_zone  = local.zone
  subnet_id          = data.sbercloud_vpc_subnet.course.id
  security_group_ids = [sbercloud_networking_secgroup.db.id]
  key_pair           = sbercloud_kps_keypair.key.name
  disk_size          = data.sbercloud_images_image.ubuntu.min_disk_gb
  public_ip          = var.debug_public_ips
  tags               = merge(local.tags, { role = "db" })

  user_data = templatefile("${path.module}/cloud-init-db.yaml.tftpl", {
    registry    = var.mirror_registry
    db_password = var.db_password
  })
}

# ---------- Серверы приложения: app-1 … app-N ----------
# range(2) = [0, 1]  →  {"app-1", "app-2"}. Поменяли app_count — добавился/удалился сервер.
locals {
  app_names = toset([for i in range(var.app_count) : "app-${i + 1}"])
}

module "app" {
  source   = "../../lesson11/modules/vm"
  for_each = local.app_names

  name               = "${var.prefix}-${each.key}"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor             = var.vm_flavor
  availability_zone  = local.zone
  subnet_id          = data.sbercloud_vpc_subnet.course.id
  security_group_ids = [sbercloud_networking_secgroup.app.id]
  key_pair           = sbercloud_kps_keypair.key.name
  disk_size          = data.sbercloud_images_image.ubuntu.min_disk_gb
  public_ip          = var.debug_public_ips
  tags               = merge(local.tags, { role = "app" })

  # Адрес базы берём из выхода модуля db — Terraform сам создаст db раньше app
  user_data = templatefile("${path.module}/cloud-init-app.yaml.tftpl", {
    name        = "${var.prefix}-${each.key}"
    registry    = var.mirror_registry
    repo_url    = var.repo_url
    db_ip       = TODO # внутренний IP базы: какой выход есть у модуля db?
    db_password = var.db_password
  })
}
