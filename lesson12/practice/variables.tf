variable "region" {
  description = "Регион облака"
  type        = string
  default     = "ru-moscow-1"
}

variable "prefix" {
  description = "Префикс команды, например ivanov-petrov. Все ресурсы называются <prefix>-…"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.prefix))
    error_message = "prefix: 3–21 символ, строчные латинские буквы, цифры и дефис, начинается с буквы."
  }
}

variable "app_count" {
  description = "Сколько ВМ с бэкендом поставить за балансировщик"
  type        = number
  default     = 2

  validation {
    condition     = var.app_count >= 1 && var.app_count <= 4
    error_message = "app_count: от 1 до 4 — квоты общего проекта не резиновые."
  }
}

# Пароль БД в код и в tfvars не пишем: export TF_VAR_db_password="…"
variable "db_password" {
  description = "Пароль PostgreSQL (латиница и цифры, от 12 символов)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9]{12,}$", var.db_password))
    error_message = "db_password: только латинские буквы и цифры, не короче 12 символов."
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
  description = "Путь к публичному SSH-ключу (.pub!)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "repo_url" {
  description = "Откуда ВМ берут код бэкенда"
  type        = string
  default     = "https://github.com/tenroman1-design/devops-lab.git"
}

variable "mirror_registry" {
  description = "Наш реестр с копиями образов Docker Hub"
  type        = string
  default     = "ghcr.io/tenroman1-design/devops-lab"
}

# Для отладки (например, на репетиции): выдать всем ВМ публичные IP и открыть SSH.
# На занятии — false: в «настоящем» кластере серверы снаружи не видны.
variable "debug_public_ips" {
  description = "true — дать ВМ публичные IP и открыть SSH (только для отладки)"
  type        = bool
  default     = false
}
