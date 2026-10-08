# Карта «сервер => публичный IP». for-выражение собирает её из всех копий модуля.
output "public_ips" {
  value = { for k, vm in module.web : k => vm.public_ip }
}

output "urls" {
  value = [for vm in module.web : "http://${vm.public_ip}/"]
}

output "ssh_commands" {
  value = { for k, vm in module.web : k => "ssh root@${vm.public_ip}" }
}
