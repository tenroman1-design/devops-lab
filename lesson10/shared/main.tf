# Занятие 10. ДЛЯ ПРЕПОДАВАТЕЛЯ: общая подсеть курса в общем проекте cloud.ru.
# Бакет для state (занятие 11) и NAT-шлюз (занятие 12) — в файле lessons11-12.tf рядом.
# Запускается ОДИН раз до занятия. Студенты подсеть только читают по имени (data source в steps/01-data.tf).
#
#   export SBC_ACCESS_KEY=...  SBC_SECRET_KEY=...
#   terraform init && terraform apply
#
# Почему общая сеть: в проекте есть квота на число VPC (обычно единицы), а студентов — десятки.
#
# Квота на VPC уже занята (ошибка VPC.0114 "Quota exceeded for resources: ['router']")?
# Тогда подсеть курса создаём в СУЩЕСТВУЮЩЕЙ VPC:
#   1) terraform plan                      — в outputs existing_vpcs / existing_subnets видно, что уже есть
#   2) terraform apply -var 'existing_vpc_name=<имя VPC>' -var 'subnet_cidr=<свободный /22 внутри её CIDR>'
#      (подсеть не должна пересекаться с существующими подсетями этой VPC)
#   Студентам ничего менять не нужно: они ищут подсеть по имени devops-course-subnet.
#   Удаление в конце курса — с теми же -var.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.12"
    }
  }
}

provider "sbercloud" {
  auth_url = "https://iam.ru-moscow-1.hc.sbercloud.ru/v3"
  region   = "ru-moscow-1"
}

variable "existing_vpc_name" {
  description = "Пусто — создать новую VPC devops-course-vpc. Имя — взять существующую VPC (если квота на VPC занята)"
  type        = string
  default     = ""
}

variable "subnet_cidr" {
  description = "CIDR подсети курса; /22 — до ~1000 адресов"
  type        = string
  default     = "192.168.8.0/22"
}

# Что уже есть в проекте — для выбора VPC и свободного CIDR
data "sbercloud_vpcs" "all" {}
data "sbercloud_vpc_subnets" "all" {}

resource "sbercloud_vpc" "course" {
  count = var.existing_vpc_name == "" ? 1 : 0
  name  = "devops-course-vpc"
  cidr  = "192.168.0.0/16"
}

# Раньше VPC создавалась без count — переносим её в state без пересоздания
moved {
  from = sbercloud_vpc.course
  to   = sbercloud_vpc.course[0]
}

data "sbercloud_vpc" "existing" {
  count = var.existing_vpc_name == "" ? 0 : 1
  name  = var.existing_vpc_name
}

locals {
  vpc_id   = var.existing_vpc_name == "" ? sbercloud_vpc.course[0].id : data.sbercloud_vpc.existing[0].id
  vpc_name = var.existing_vpc_name == "" ? sbercloud_vpc.course[0].name : data.sbercloud_vpc.existing[0].name
  vpc_cidr = var.existing_vpc_name == "" ? sbercloud_vpc.course[0].cidr : data.sbercloud_vpc.existing[0].cidr
}

resource "sbercloud_vpc_subnet" "course" {
  name       = "devops-course-subnet"
  cidr       = var.subnet_cidr
  gateway_ip = cidrhost(var.subnet_cidr, 1)
  vpc_id     = local.vpc_id
}

output "existing_vpcs" {
  value = [for v in data.sbercloud_vpcs.all.vpcs : "${v.name}  ${v.cidr}"]
}

output "existing_subnets" {
  value = [for s in data.sbercloud_vpc_subnets.all.subnets : "${s.name}  ${s.cidr}  (vpc ${s.vpc_id})"]
}

output "vpc" {
  value = "${local.vpc_name} ${local.vpc_cidr}"
}

output "subnet" {
  value = "${sbercloud_vpc_subnet.course.name} ${sbercloud_vpc_subnet.course.cidr}"
}
