# Занятие 15. Введение в мониторинг: Prometheus и Grafana на своей ВМ

Теория — 40 минут (слайды `Занятие 15 — Введение в мониторинг.pptx`). Практика — 80 минут.

Работаем на **своей ВМ с Ubuntu Server в VirtualBox**, которую вы создали в начале курса (раздел «Windows → VirtualBox + Ubuntu Server» в README репозитория). Стек поднимаем в Docker Compose, как на занятиях 8–9. Облако сегодня не используем.

```
Ноутбук (Windows)                         ВМ Ubuntu Server · 2 CPU · 4 ГБ RAM
 браузер: localhost:3000, :9090, :9093  ──►  docker compose
 терминал: ssh -p 2222 …@localhost           ├─ prometheus      собирает и хранит метрики   :9090
                                             ├─ node-exporter   метрики самой ВМ
                                             ├─ alertmanager    отправка алертов            :9093
                                             ├─ grafana         дашборды                    :3000
                                             └─ podinfo         тестовое приложение         :9898
```

Мониторим саму ВМ (через node-exporter) и приложение podinfo.

## Подготовка (до занятия, 10 минут)

**1. Проброс портов.** VirtualBox → ваша ВМ → **Настроить → Сеть → Адаптер 1 (NAT) → Дополнительно → Проброс портов**. К уже существующим правилам (ssh, app, web) добавьте три:

| Имя | Порт хоста | Порт гостя | Зачем |
|---|---|---|---|
| grafana | 3000 | 3000 | Grafana в браузере Windows |
| prometheus | 9090 | 9090 | Prometheus в браузере Windows |
| alertmanager | 9093 | 9093 | Alertmanager в браузере Windows |

Протокол TCP, IP-адреса оставьте пустыми. Правила можно добавить и на включённой ВМ.

**2. Зайдите на ВМ и проверьте её** (из Windows Terminal / PowerShell):

```bash
ssh -p 2222 <ваш_пользователь>@localhost
docker compose version            # Docker и Compose работают
free -h                           # в колонке available не меньше 2 ГБ
df -h /                           # свободно не меньше 5 ГБ
```

**3. Обновите репозиторий курса и скачайте образы.** Docker Hub работает нестабильно, поэтому образы берём скриптом: он сначала пробует наш реестр, потом официальные реестры проектов.

```bash
cd ~/devops-lab && git pull
cd lesson15/practice
bash pull-monitoring-images.sh
```

> **Mac без ВМ.** Если вы работаете в Docker Desktop на Mac, в `docker-compose.yml` у сервиса `node-exporter` удалите строки `pid: host` и весь блок `volumes`. Метрики будут показывать внутреннюю ВМ Docker Desktop, для занятия этого достаточно. Адреса в браузере те же: `localhost:3000` и так далее.

Все команды ниже выполняются **внутри ВМ**, в папке `~/devops-lab/lesson15/practice`. Браузер — на ноутбуке.

## Практика

| Часть | Что делаем | Время |
|---|---|---|
| 1 | Поднимаем стек одной командой | 15 мин |
| 2 | Prometheus: цели и запросы PromQL | 15 мин |
| 3 | Grafana: источник данных и готовый дашборд | 15 мин |
| 4 | Добавляем podinfo в Prometheus и создаём нагрузку | 10 мин |
| 5 | Алерт PodinfoDown и Alertmanager | 15 мин |
| 6 | Своя панель в Grafana и уборка | 10 мин |

### Часть 1. Стек одной командой (15 мин)

```bash
cp .env.example .env
nano .env                          # впишите свой пароль в GRAFANA_PASSWORD
docker compose config --quiet && echo OK
docker compose up -d
docker compose ps
```

У всех пяти сервисов статус `running` (или `Up`). Если какой-то сервис перезапускается, посмотрите причину: `docker compose logs <сервис>`.

Вопрос для себя: откуда Prometheus берёт свой конфиг и файл правил? Ответ — в `docker-compose.yml`, в секции `volumes` сервиса `prometheus`.

### Часть 2. Prometheus: цели и запросы (15 мин)

В браузере на ноутбуке откройте `http://localhost:9090` → **Status → Targets**.

1. Найдите цели `prometheus` и `node`. Какой у них статус?
2. На вкладке **Graph** выполните запрос `up`. Что означают значения `1` и `0`?
3. Сколько памяти свободно на ВМ, в гигабайтах: `node_memory_MemAvailable_bytes / 1024 / 1024 / 1024`. Сравните с выводом `free -h` в терминале.
4. Сколько ядер ВМ занято работой: `sum(rate(node_cpu_seconds_total{mode!="idle"}[1m]))`.
5. Нагрузите процессор ВМ и посмотрите, как меняется график из пункта 4 (вкладка **Graph**, режим графика):

   ```bash
   timeout 90 yes > /dev/null &
   ```

   Через 90 секунд команда остановится сама.

### Часть 3. Grafana (15 мин)

Откройте `http://localhost:3000`, логин `admin`, пароль из `.env`. Источник данных Prometheus уже подключён: его описывает файл в `grafana/provisioning/datasources`.

1. **Dashboards → New → Import**, введите ID `1860` (Node Exporter Full), нажмите **Load**, выберите источник Prometheus и нажмите **Import**.
2. Найдите на дашборде загрузку процессора и использование памяти. Совпадают ли цифры с тем, что вы видели в части 2?

> Если импорт по ID не работает (Grafana не может скачать дашборд из интернета), пропустите этот пункт: в части 6 вы построите панель сами.

Вопрос для себя: почему источник данных появился сам, без ручной настройки?

### Часть 4. Добавляем podinfo (10 мин)

podinfo уже запущен. Убедитесь, что он отдаёт метрики, и найдите счётчик запросов:

```bash
curl -s localhost:9898/metrics | grep -E '^http_request' | head
```

Prometheus пока не знает о podinfo. Откройте `prometheus/prometheus.yml` и на месте TODO добавьте job с именем `podinfo` и целью `podinfo:9898`.

> Внутри сети Compose контейнеры обращаются друг к другу по имени сервиса. Для Prometheus `localhost` — это он сам, поэтому цель пишется как `podinfo:9898`.

Перезапустите Prometheus и подождите 30 секунд:

```bash
docker compose restart prometheus
```

В **Status → Targets** цель `podinfo` должна стать `UP`. Создайте нагрузку:

```bash
for i in $(seq 1 500); do curl -s -o /dev/null localhost:9898/; done
```

Постройте в Prometheus график скорости запросов: `rate(<имя счётчика из curl>[1m])`. Подсказка: подойдёт метрика, имя которой заканчивается на `_total` или `_count`.

Вопрос для себя: почему для счётчика почти всегда берут `rate()`, а не значение как есть?

### Часть 5. Алерт PodinfoDown (15 мин)

Откройте `prometheus/alerts.yml` и на месте TODO добавьте правило:

- `alert: PodinfoDown`;
- условие `up{job="podinfo"} == 0`;
- `for: 1m`;
- метка `severity: critical`.

Образец лежит в `../solution/alerts.yml`. Смотрите его, только если застряли больше чем на 5 минут.

```bash
docker compose restart prometheus
```

В **Status → Rules** появится правило, во вкладке **Alerts** оно будет в состоянии *Inactive*. Остановите приложение:

```bash
docker compose stop podinfo
```

Через 15–30 секунд алерт перейдёт в *Pending*, ещё через минуту — в *Firing*. Откройте Alertmanager: `http://localhost:9093` — алерт должен быть там. Верните приложение:

```bash
docker compose start podinfo
```

### Часть 6. Своя панель и уборка (10 мин)

В Grafana: **Dashboards → New → New dashboard → Add visualization**, источник Prometheus.

- запрос: `rate(...[1m])` по счётчику из части 4;
- тип: **Time series**;
- название панели: `Запросы к podinfo в секунду`.

Сохраните дашборд под своим именем. Запустите цикл `curl` из части 4 ещё раз и посмотрите, как меняется график.

**Уборка — обязательна**, иначе стек продолжит занимать память ВМ:

```bash
docker compose down -v
```

Флаг `-v` удаляет тома с данными. Образы остаются, их можно использовать при выполнении ДЗ.

## Что сдавать

Домашнее задание — `HOMEWORK.md` в папке занятия. Сдача — файлом в чат группы до следующего занятия.

## Типичные проблемы

| Симптом | Что делать |
|---|---|
| `localhost:3000` не открывается в Windows | Нет проброса порта: VirtualBox → Сеть → Проброс портов (см. подготовку). Проверьте и внутри ВМ: `curl -I localhost:3000`. |
| `GRAFANA_PASSWORD` не задан | Создайте `.env` из `.env.example` и снова выполните `docker compose up -d`. |
| `pull` зависает или падает с `403`, `toomanyrequests` | Запустите `bash pull-monitoring-images.sh`. Если не помогло — подключите зеркала Docker Hub (README курса). |
| Цель в состоянии `DOWN` | Проверьте имя сервиса и порт в `prometheus.yml`, затем `docker compose logs prometheus`. |
| Prometheus не стартует после правки | Ошибка в YAML: `docker compose logs prometheus` покажет строку. Проверьте отступы. |
| Контейнеры падают, в логах `OOM` или `Killed` | Мало памяти в ВМ: `free -h`. Остановите другие стеки (`docker ps`, затем `docker compose down` в их папках). |
| `permission denied` на docker.sock | `sudo usermod -aG docker $USER`, выйдите из SSH и зайдите снова. |
