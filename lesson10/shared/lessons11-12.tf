# Занятия 11–12. ДЛЯ ПРЕПОДАВАТЕЛЯ: общие ресурсы курса, которые включаются переключателями.
# Удобнее всего задать их в terraform.tfvars этой папки (в Git он не попадает):
#
#   state_bucket = "hse-devops-tfstate"   # перед занятием 11: бакет OBS для state студентов
#   enable_nat   = true                   # перед занятием 12: выход в интернет для ВМ без публичного IP
#
# затем  terraform plan && terraform apply.  Выключить NAT после занятия 12:  enable_nat = false → apply.

variable "state_bucket" {
  description = "Имя бакета OBS для state студентов (пусто — не создавать). Имя должно быть уникальным во всём OBS"
  type        = string
  default     = ""
}

variable "enable_nat" {
  description = "true — создать NAT-шлюз: ВМ без публичного IP получают выход в интернет (apt, git, docker pull)"
  type        = bool
  default     = false
}

# ---------- Занятие 11: бакет для удалённого state ----------
resource "sbercloud_obs_bucket" "state" {
  count = var.state_bucket == "" ? 0 : 1

  bucket        = var.state_bucket
  acl           = "private"
  versioning    = true  # старые версии state сохраняются — можно откатить испорченный state
  force_destroy = false # не удалять бакет, пока в нём есть state студентов

  tags = {
    course = "hse-devops"
  }
}

# ---------- Занятие 12: NAT-шлюз для всей подсети курса ----------
resource "sbercloud_vpc_eip" "nat" {
  count = var.enable_nat ? 1 : 0

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "devops-course-nat-bw"
    share_type  = "PER"
    size        = 10
    charge_mode = "traffic"
  }
}

resource "sbercloud_nat_gateway" "course" {
  count = var.enable_nat ? 1 : 0

  name      = "devops-course-nat"
  spec      = "1" # самый маленький
  vpc_id    = local.vpc_id
  subnet_id = sbercloud_vpc_subnet.course.id
}

# SNAT: всё, что выходит из подсети курса в интернет, — через публичный IP шлюза
resource "sbercloud_nat_snat_rule" "course" {
  count = var.enable_nat ? 1 : 0

  nat_gateway_id = sbercloud_nat_gateway.course[0].id
  floating_ip_id = sbercloud_vpc_eip.nat[0].id
  subnet_id      = sbercloud_vpc_subnet.course.id
}

output "state_bucket" {
  value = var.state_bucket == "" ? "не создан" : sbercloud_obs_bucket.state[0].bucket
}

output "nat" {
  value = var.enable_nat ? "NAT включён, внешний IP ${sbercloud_vpc_eip.nat[0].address}" : "NAT выключен"
}
