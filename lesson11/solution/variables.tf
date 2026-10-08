variable "region" {
  description = "Регион облака"
  type        = string
  default     = "ru-moscow-1"
}

variable "prefix" {
  description = "Ваш префикс — фамилия латиницей. Все ресурсы называются <prefix>-…"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.prefix))
    error_message = "prefix: 3–21 символ, строчные латинские буквы, цифры и дефис, начинается с буквы."
  }
}

# Какие серверы создать. Ключ карты — короткое имя сервера, значение — его настройки.
# Добавили строку — появился сервер. Удалили строку — удалился ровно этот сервер.
variable "servers" {
  description = "Серверы: имя => настройки"
  type = map(object({
    disk_size = optional(number, 10)
  }))
  default = {
    "web-1" = {}
    "web-2" = {}
  }
}

variable "subnet_name" {
  description = "Общая подсеть курса"
  type        = string
  default     = "devops-course-subnet"
}

variable "image_name_regex" {
  description = "Шаблон имени публичного образа ОС"
  type        = string
  default     = "^Ubuntu 22.04 server 64bit$"
}

variable "vm_flavor" {
  description = "Тип ВМ"
  type        = string
  default     = "s7n.medium.2"
}

variable "ssh_public_key_path" {
  description = "Путь к ВАШЕМУ публичному SSH-ключу (.pub!)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidr" {
  description = "С каких адресов разрешён SSH"
  type        = string
  default     = "0.0.0.0/0"
}
