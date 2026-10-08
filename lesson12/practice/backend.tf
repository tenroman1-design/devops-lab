# State занятия 12 — в том же бакете OBS, что и в занятии 11, но под своим ключом.
# Переменные в блоке backend нельзя, поэтому ключ передаём при init:
#   export AWS_ACCESS_KEY_ID="$SBC_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SBC_SECRET_KEY"
#   terraform init -backend-config="key=<prefix>/lesson12.tfstate"
#
# Блокировки state нет: apply в команде запускает один человек («водитель»).

terraform {
  backend "s3" {
    bucket = "hse-devops-tfstate" # имя бакета скажет преподаватель
    region = "ru-moscow-1"
    endpoints = {
      s3 = "https://obs.ru-moscow-1.hc.sbercloud.ru"
    }

    # OBS — не Amazon: отключаем проверки, которые есть только в AWS
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
