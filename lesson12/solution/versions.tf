# Занятие 12 — ГОТОВОЕ РЕШЕНИЕ: кластер приложения за балансировщиком.

terraform {
  required_version = ">= 1.6"

  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.12"
    }
  }
}

# Ключи — только из переменных окружения SBC_ACCESS_KEY / SBC_SECRET_KEY
provider "sbercloud" {
  auth_url = "https://iam.ru-moscow-1.hc.sbercloud.ru/v3"
  region   = var.region
}
