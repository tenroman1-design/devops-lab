# ЧАСТЬ 1: один сервер — один IP
output "public_ip" {
  value = module.web.public_ip
}

output "url" {
  value = "http://${module.web.public_ip}/"
}

# ЧАСТЬ 2: когда серверов станет несколько (for_each), замените выходы выше на эти:
#
# output "public_ips" {
#   value = { for k, vm in module.web : k => vm.public_ip }
# }
#
# output "urls" {
#   value = [for vm in module.web : "http://${vm.public_ip}/"]
# }
