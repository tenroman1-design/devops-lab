#!/usr/bin/env bash
# Скачивает образы занятия 15 и даёт им имена из docker-compose.yml.
# Порядок источников: реестр курса (GHCR) → официальный реестр проекта (quay.io / ghcr.io) → Docker Hub.
# Запуск внутри ВМ:  bash pull-monitoring-images.sh
set -uo pipefail

REG="ghcr.io/tenroman1-design/devops-lab"

# привычное имя | имя в реестре курса | официальная копия вне Docker Hub (или -)
IMAGES=(
  "prom/prometheus:v2.53.0|prometheus:v2.53.0|quay.io/prometheus/prometheus:v2.53.0"
  "prom/node-exporter:v1.8.1|node-exporter:v1.8.1|quay.io/prometheus/node-exporter:v1.8.1"
  "prom/alertmanager:v0.27.0|alertmanager:v0.27.0|quay.io/prometheus/alertmanager:v0.27.0"
  "grafana/grafana:11.1.0|grafana:11.1.0|-"
  "stefanprodan/podinfo:6.7.0|podinfo:6.7.0|ghcr.io/stefanprodan/podinfo:6.7.0"
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
