# Модулю тоже нужно знать, из какого провайдера его ресурсы.
# Блока provider здесь нет: настройки провайдера модуль получает от вызывающего кода.
terraform {
  required_providers {
    sbercloud = {
      source = "sbercloud-terraform/sbercloud"
    }
  }
}
