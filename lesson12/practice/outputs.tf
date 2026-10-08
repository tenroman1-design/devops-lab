output "url" {
  description = "Адрес сервиса — через балансировщик"
  value       = "http://${sbercloud_vpc_eip.lb.address}/"
}

output "app_private_ips" {
  value = { for k, vm in module.app : k => vm.private_ip }
}

output "db_private_ip" {
  value = module.db.private_ip
}

# Заполнено только при debug_public_ips = true
output "debug_public_ips" {
  value = var.debug_public_ips ? merge(
    { db = module.db.public_ip },
    { for k, vm in module.app : k => vm.public_ip }
  ) : {}
}
