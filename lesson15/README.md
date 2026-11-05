# Занятие 15. Мониторинг: Grafana, cAdvisor и проверка приложения снаружи

На занятии 14 мы собрали метрики ВМ и научились писать запросы PromQL. Смотреть на цифры в консоли Prometheus неудобно. Сегодня добавляем **Grafana** — она рисует графики и дашборды по данным Prometheus. Ещё добавляем две вещи, которые отвечают на вопросы «что в контейнерах» и «отвечает ли приложение для пользователя».

Это второе занятие модуля «Мониторинг» (14 — Prometheus, 15 — Grafana, 16 — Alertmanager).

```
Prometheus  ◀──  node-exporter   метрики ВМ
   ▲        ◀──  cadvisor        метрики контейнеров
   │        ◀──  blackbox        «отвечает ли /health через nginx» (проверка снаружи)
   │
   ▼
Grafana  →  дашборд «Курс DevOps» (графики)
   │
   └── 127.0.0.1:3000 — смотрим через SSH-туннель
```

**Длительность:** 30 минут теория, 90 минут практика.

---

## Часть 1. Теория (30 мин)

### 1.1. Что делает Grafana

Grafana не хранит метрики и не собирает их. Она **показывает** то, что уже есть в источнике данных. Наш источник — Prometheus, он задан в `grafana/provisioning/datasources/prometheus.yml`.

Основные понятия:
- **Источник данных (data source)** — откуда берём данные. У нас один: Prometheus.
- **Панель (panel)** — один график или одна цифра. В панели стоит запрос PromQL, который мы уже писали на занятии 14.
- **Дашборд (dashboard)** — набор панелей на одной странице.
- **Provisioning** — настройка Grafana файлами, а не кликами. Источник и дашборды описаны в Git, поэтому их можно восстановить после пересоздания ВМ.

### 1.2. Белый ящик и чёрный ящик

Есть два способа проверять сервис:
- **Белый ящик** (white-box): метрики изнутри. node-exporter и cAdvisor видят ресурсы ВМ и контейнеров.
- **Чёрный ящик** (black-box): проверка снаружи, как это видит пользователь. Например, «отвечает ли `/health` через nginx с HTTP 200».

Оба нужны. Белый ящик скажет, что память на исходе. Чёрный ящик скажет, что пользователи уже не могут открыть сайт. Для второго используем **blackbox_exporter**: Prometheus просит его проверить адрес, а blackbox делает HTTP-запрос и возвращает результат в виде метрик (`probe_success`, `probe_duration_seconds`).

### 1.3. cAdvisor: метрики контейнеров

node-exporter видит ВМ целиком, но не разбивает нагрузку по контейнерам. **cAdvisor** от Google смотрит на каждый контейнер: память, CPU, сеть. Его метрики начинаются с `container_`. Фильтр по имени контейнера выделяет наш стек: `name=~"devops-lab.*"`.

### 1.4. Как читать дашборд

Правило простое: **одна панель — один вопрос**.
- Сколько CPU занято? — график загрузки.
- Хватает ли памяти? — график доступной памяти в процентах.
- Отвечает ли приложение? — одна цифра: 1 или 0.

Если на панели ничего не видно, первым делом проверьте промежуток времени справа сверху и сам запрос в режиме **Code**.

---

## Часть 2. Практика (90 мин)

Работаем на той же ВМ. Стек из занятия 14 нужно остановить: в этом занятии он заменяется стеком занятия 15 (имя проекта одно и то же, `monitoring`).

### Подготовка (10 мин)

- [ ] ВМ работает, приложение поднято cloud-init (`cloud-init status --wait` → `status: done`).
- [ ] Обновите репозиторий на ВМ и остановите стек занятия 14 (тома не удаляем):
  ```bash
  cd /opt/devops-lab && git pull
  cd lesson14/practice && docker compose down
  cd ../../lesson15/practice
  ```
- [ ] Создайте файл `.env` с паролем Grafana:
  ```bash
  cp .env.example .env
  sed -i "s/замените-на-свой-пароль/$(openssl rand -hex 12)/" .env
  ```
  Пароль не записывайте в ДЗ и в чат. Он нужен только для входа в Grafana.
- [ ] **Два туннеля** на ноутбуке (в отдельном окне, оставить открытым):
  ```bash
  ssh -L 9090:127.0.0.1:9090 -L 3000:127.0.0.1:3000 root@<public_ip>
  ```
  Тогда `http://localhost:3000` откроет Grafana, `http://localhost:9090` — Prometheus.

### Часть 1. Поднимаем стек (15 мин)

```bash
docker compose up -d
docker compose ps          # 5 сервисов: prometheus, node-exporter, cadvisor, blackbox, grafana — Up
```

Войдите в Grafana: пользователь `admin`, пароль из `.env`. Откройте **Connections → Data sources → Prometheus** и нажмите **Save & test**: должно появиться «Successfully queried the Prometheus API». Источник создан автоматически из файла.

### Часть 2. Два новых job в Prometheus (25 мин)

Откройте `prometheus/prometheus.yml`. В нём два TODO.

**TODO 1.** Добавьте job `cadvisor`: адрес `cadvisor:8080`. Блок такой же, как у `node`.

**TODO 2.** Заполните `targets` у job `backend-http`: впишите адрес проверки `http://nginx/health`. Остальной блок уже готов: relabel-правила передают адрес в blackbox.

Примените:
```bash
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
docker compose restart prometheus
```

На вкладке **Targets** должны быть четыре job, все `UP`. В поиске выполните `probe_success{job="backend-http"}`: значение `1`.

> Застряли больше 5 минут — посмотрите `../solution/prometheus/prometheus.yml`.

Почему для `backend-http` адрес `blackbox:9115`, а не `nginx`? Подсказка: Prometheus ходит в blackbox, а blackbox уже ходит в nginx.

### Часть 3. Дашборд (30 мин)

В Grafana создайте дашборд: **Dashboards → New → New dashboard → Add visualization**, источник — Prometheus. Сделайте три панели:

| Панель | Запрос (вкладка Code) | Тип |
|---|---|---|
| Загрузка CPU, % | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | Time series |
| Доступная память, % | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` | Time series |
| Приложение отвечает | `probe_success{job="backend-http"}` | Stat |

Сохраните дашборд. Затем **Export → Export as JSON → Save to file**. Положите файл на ВМ в `grafana/dashboards/lab-overview.json`: через `nano`, вставив содержимое JSON. Перезапустите Grafana:

```bash
docker compose restart grafana
```

Проверьте, что дашборд появился в папке **Курс DevOps** и не теряется после перезапуска.

> Эталон для сравнения: `../solution/grafana/dashboards/lab-overview.json`. Он содержит пять панелей.

### Часть 4. Ломаем приложение (15 мин)

На ВМ остановите backend приложения (это стек занятия 9):

```bash
cd /opt/devops-lab/lesson09 && docker compose stop backend
```

Через 15–30 секунд панель «Приложение отвечает» покажет `0`. Загляните в `probe_duration_seconds`: ответ от nginx пришёл, но ошибочный. Вернём всё:

```bash
docker compose start backend
cd /opt/devops-lab/lesson15/practice
```

Обратите внимание: node-exporter и cAdvisor не заметили поломки. Они видят ресурсы, а не то, отвечает ли приложение. Поэтому нужны обе проверки.

### Часть 5. Граница и уборка (10 мин)

Что Grafana **не** делает:
- не отправляет уведомлений: дашборд ждёт, пока на него кто-то посмотрит. Уведомления появятся на занятии 16 через Alertmanager;
- не хранит метрики: их хранит Prometheus.

Вопрос в зал: почему мы показываем на одном дашборде и ресурсы ВМ, и проверку `/health`? Ответ: ресурсы объясняют причину, а проверка снаружи показывает, что пользователь реально страдает.

> ⛔ **Уборка:** стек остаётся запущенным: он понадобится на занятии 16. В конце модуля выполните `terraform destroy` в `lesson11/practice`.

---

## Итоги занятия

- Grafana показывает данные Prometheus. Источник и дашборд описываются файлами (provisioning), а не кликами.
- Белый ящик (node-exporter, cAdvisor) показывает ресурсы. Чёрный ящик (blackbox) показывает, работает ли сервис для пользователя.
- Одна панель отвечает на один вопрос.
- Пароль Grafana лежит в `.env`, в Git его нет.

## Домашнее задание

См. [HOMEWORK.md](HOMEWORK.md). Сдаётся файлом в чат группы до занятия 16.

## Файлы занятия

| Файл | Что это |
|---|---|
| `practice/docker-compose.yml` | стек: Prometheus, node-exporter, cAdvisor, blackbox, Grafana |
| `practice/.env.example` | шаблон `.env` с паролем Grafana |
| `practice/prometheus/prometheus.yml` | конфиг Prometheus с TODO 1 и TODO 2 |
| `practice/blackbox/blackbox.yml` | модуль проверки HTTP |
| `practice/grafana/provisioning/` | источник данных и загрузка дашбордов |
| `practice/grafana/dashboards/` | сюда кладём JSON дашборда (пустая папка) |
| `solution/` | полное решение, включая эталонный дашборд `lab-overview.json` |
| `HOMEWORK.md` | домашнее задание |
