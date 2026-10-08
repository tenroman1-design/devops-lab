# Выходы модуля: что вызывающий код может прочитать как module.<имя>.<выход>

output "id" {
  value = sbercloud_compute_instance.this.id
}

output "name" {
  value = sbercloud_compute_instance.this.name
}

output "private_ip" {
  value = sbercloud_compute_instance.this.access_ip_v4
}

# null, если public_ip = false
output "public_ip" {
  value = var.public_ip ? sbercloud_vpc_eip.this[0].address : null
}
