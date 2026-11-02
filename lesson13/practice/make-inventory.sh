#!/usr/bin/env bash
# Собирает inventory.ini из выхода Terraform: IP ВМ берём из занятия 11, руками ничего не вписываем.
# Запуск из lesson13/practice:   ./make-inventory.sh
# Другой путь к Terraform:       ./make-inventory.sh ../../lesson11/solution
set -euo pipefail

TF_DIR="${1:-../../lesson11/practice}"
KEY="${ANSIBLE_KEY:-$HOME/.ssh/id_ed25519}"

IP="$(terraform -chdir="$TF_DIR" output -raw public_ip)"

cat > inventory.ini <<INV
[web]
$IP ansible_user=root ansible_ssh_private_key_file=$KEY
INV

echo "inventory.ini: группа web -> $IP"
