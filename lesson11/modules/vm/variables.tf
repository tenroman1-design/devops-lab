# Входы модуля: всё, что модулю нужно знать снаружи.
# Модуль ничего не ищет сам — образ, подсеть, ключ и группы безопасности ему передают.

variable "name" {
  description = "Имя ВМ (и префикс для её ресурсов)"
  type        = string
}

variable "image_id" {
  description = "ID образа ОС"
  type        = string
}

variable "flavor" {
  description = "Тип ВМ, например s7n.medium.2"
  type        = string
}

variable "availability_zone" {
  description = "Зона доступности"
  type        = string
}

variable "subnet_id" {
  description = "ID подсети, в которую подключается ВМ"
  type        = string
}

variable "security_group_ids" {
  description = "Группы безопасности ВМ"
  type        = list(string)
}

variable "key_pair" {
  description = "Имя SSH-ключа в облаке"
  type        = string
}

variable "user_data" {
  description = "cloud-init. null — без него"
  type        = string
  default     = null
}

variable "disk_size" {
  description = "Размер системного диска, ГБ (не меньше минимума образа)"
  type        = number
  default     = 10
}

variable "public_ip" {
  description = "true — выдать ВМ публичный IP (EIP), false — только внутренний адрес"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Теги ВМ"
  type        = map(string)
  default     = {}
}
