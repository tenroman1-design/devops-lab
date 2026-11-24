#!/usr/bin/env bash
# Скачивает образы занятия 16 и даёт им имена из docker-compose.yml.
# Порядок источников: реестр курса (GHCR) → официальный реестр проекта (quay.io / ghcr.io) → Docker Hub.
# Запуск внутри ВМ:  bash pull-logging-images.sh
set -uo pipefail

REG="ghcr.io/tenroman1-design/devops-lab"

# привычное имя | имя в реестре курса | официальная копия вне Docker Hub (или -)
IMAGES=(
  "grafana/loki:3.5.1|loki:3.5.1|-"
  "grafana/alloy:v1.10.2|alloy:v1.10.2|-"
  "grafana/grafana:11.1.0|grafana:11.1.0|-"
  "python:3.12-slim|python:3.12-slim|-"
)

missing=0
for line in "${IMAGES[@]}"; do
  IFS='|' read -r name course alt <<<"$line"
  echo "==> $name"
  if docker image inspect "$name" >/dev/null 2>&1; then echo "    уже есть"; continue; fi
  for src in "$REG/$course" "$alt" "$name"; do
    [ "$src" = "-" ] && continue
    if docker pull -q "$src" >/dev/null 2>&1; then
      [ "$src" != "$name" ] && docker tag "$src" "$name"
      echo "    OK из $src"; break
    fi
  done
  docker image inspect "$name" >/dev/null 2>&1 || { echo "    НЕ скачался"; missing=1; }
done

echo
if [ "$missing" = 0 ]; then
  echo "Готово: все образы на месте."
else
  echo "Часть образов не скачалась. Подключите зеркала Docker Hub (README курса, раздел «Зеркала Docker Hub») и запустите скрипт снова."
  exit 1
fi
