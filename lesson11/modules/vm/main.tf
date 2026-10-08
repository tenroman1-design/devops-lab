# Модуль «одна ВМ»: машина + (по желанию) публичный IP.
# Тот же код, что в занятии 10, только все конкретные значения стали переменными.

resource "sbercloud_compute_instance" "this" {
  name               = var.name
  image_id           = var.image_id
  flavor_id          = var.flavor
  availability_zone  = var.availability_zone
  security_group_ids = var.security_group_ids
  key_pair           = var.key_pair
  user_data          = var.user_data

  system_disk_type = "SAS"
  system_disk_size = var.disk_size

  network {
    uuid = var.subnet_id
  }

  tags = var.tags
}

# count = 1 или 0 — так в Terraform делают «ресурс по условию»
resource "sbercloud_vpc_eip" "this" {
  count = var.public_ip ? 1 : 0

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.name}-bw"
    share_type  = "PER"
    size        = 5
    charge_mode = "traffic"
  }
}

resource "sbercloud_compute_eip_associate" "this" {
  count = var.public_ip ? 1 : 0

  public_ip   = sbercloud_vpc_eip.this[0].address
  instance_id = sbercloud_compute_instance.this.id
}
