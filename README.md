# devops-lab — учебный проект для модулей 3–4

Сервис: **backend (Flask) + PostgreSQL + Redis**, перед ним — **Nginx**, а на занятии 10 — своя ВМ в облаке cloud.ru через **Terraform**.

| Эндпоинт | Что делает |
|---|---|
| `GET /` | версия и имя контейнера (`served_by`), который ответил |
| `GET /health` | проверяет связь с PostgreSQL и Redis (200 / 503) |
| `GET /hits` | счётчик в Redis |
| `GET/POST /notes` | заметки в PostgreSQL: `{"text": "..."}` |

**Перед первым занятием** пройдите раздел [«Подготовка ноутбука»](#подготовка-ноутбука) — на практике времени на установку не будет.

## Содержание
- [Подготовка ноутбука](#подготовка-ноутбука)
  - [Windows → VirtualBox + Ubuntu Server](#windows--virtualbox--ubuntu-server)
  - [Docker в Ubuntu (VirtualBox)](#docker-и-docker-compose-в-ubuntu-вм-virtualbox)
  - [Docker на macOS](#docker-и-docker-compose-на-macos)
  - [Образы курса из GHCR](#образы-курса-из-нашего-реестра-ghcr)
  - [Terraform → подготовка к занятию 10](lesson10/README.md#подготовка)
- [Занятия 8–12: README, практика и домашние задания](#занятия)
- [Если что-то не работает](#если-что-то-не-работает)

## Структура репозитория

```
app/                      код, Dockerfile, тесты
lesson08/                 занятие 8: docker-compose.yml (пароли захардкожены намеренно), README + ДЗ
lesson09/                 занятие 9: + Nginx перед бэкендом, конфигурация в .env, README + ДЗ
lesson10/README.md        занятие 10: подготовка, практика, ДЗ
lesson10/practice/        ваша рабочая папка Terraform
lesson10/steps/           шаги 01…05: data sources, firewall, SSH-ключ, ВМ + IP, nginx через cloud-init
lesson10/terraform/       готовое решение занятия 10 (ответы)
lesson10/shared/          общая сеть курса, бакет для state, NAT-шлюз (запускает преподаватель)
lesson10/ansible/         Ansible: Docker на ВМ и выкатка стека (понадобится позже)
lesson11/modules/vm/      занятие 11: модуль «ВМ» (используется и в занятии 12)
lesson11/practice/        занятие 11: рабочая папка — модуль, for_each, state в облаке
lesson11/solution/        готовое решение занятия 11
lesson12/practice/        занятие 12: кластер — балансировщик + app-серверы + БД
lesson12/solution/        готовое решение занятия 12
extras/cicd/, .github/    заготовки CI/CD на будущее (в курсе пока не используются) и копирование образов в GHCR
scripts/pull-images.sh    скачать образы курса из GHCR
```

---

## Подготовка ноутбука

Выберите свою ОС: на Windows всё ставится внутрь виртуальной машины Ubuntu (VirtualBox), на Mac — напрямую. Установка Docker расписана ниже отдельно для [Ubuntu](#docker-и-docker-compose-в-ubuntu-вм-virtualbox) и [macOS](#docker-и-docker-compose-на-macos).

| Инструмент | Зачем | Занятие |
|---|---|---|
| Docker + Docker Compose | запуск контейнеров | 8–9 |
| Git + аккаунт GitHub + SSH-ключ | код; SSH-ключ — вход на ВМ в облаке | 8–10 |
| git-filter-repo | чистка истории от секретов | 9 |
| Terraform | создание ВМ в облаке | 10 |
| Ansible | настройка ВМ | позже |
| Редактор (VS Code) | удобно, но не обязательно | — |

### Windows → VirtualBox + Ubuntu Server

На Windows работаем внутри виртуальной машины с Ubuntu Server: там те же команды, что на серверах в облаке, и работает Ansible. Docker ставим **внутрь ВМ**, Docker Desktop на Windows для курса не нужен.

**Требования:** 8 ГБ ОЗУ на ноутбуке (ВМ заберёт 4 ГБ), 30 ГБ свободного места, включённая виртуализация (Intel VT-x / AMD-V) в BIOS.

#### 1. Установка ВМ
1. Скачайте и установите [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (Windows hosts).
2. Скачайте образ [Ubuntu Server 24.04 LTS](https://ubuntu.com/download/server) (`.iso`).
3. VirtualBox → **Создать**: имя `devops`, ISO — скачанный образ, галочку «Пропустить автоматическую установку» **поставить**. Ресурсы: **2 CPU, 4096 МБ RAM, диск 25 ГБ**.
4. Запустите ВМ и пройдите установщик Ubuntu. Всё по умолчанию, кроме двух моментов:
   - придумайте имя пользователя и пароль (запомните!);
   - на шаге **SSH Setup** отметьте **Install OpenSSH server**.
5. После установки: **Reboot Now**, при запросе извлеките ISO (Устройства → Оптические диски).

#### 2. Проброс портов (чтобы заходить из Windows)
Выключите ВМ → **Настроить → Сеть → Адаптер 1 (NAT) → Дополнительно → Проброс портов** и добавьте правила:

| Имя | Порт хоста | Порт гостя | Зачем |
|---|---|---|---|
| ssh | 2222 | 22 | подключаться к ВМ по SSH |
| app | 8000 | 8000 | backend (занятия 8–9) |
| app1 | 8001 | 8001 | реплики при `--scale` |
| app2 | 8002 | 8002 | реплики при `--scale` |
| web | 8080 | 80 | nginx |

Протокол TCP, IP-адреса оставьте пустыми.

#### 3. Подключение из Windows
Запустите ВМ (можно «Запустить → Запуск в фоновом режиме») и работайте из **Windows Terminal / PowerShell**, а не из окна VirtualBox — так работает копирование и вставка:
```powershell
ssh -p 2222 <ваш_пользователь>@localhost
```
Удобнее всего — **VS Code** с расширением **Remote - SSH**: Connect to Host → `<ваш_пользователь>@localhost:2222`. Редактируете файлы прямо внутри ВМ.

#### 4. Всё остальное — внутри ВМ
```bash
sudo apt update && sudo apt -y upgrade
sudo apt install -y git curl unzip ansible pipx
pipx ensurepath && pipx install git-filter-repo
```
Docker и Docker Compose — см. раздел [Docker в Ubuntu](#docker-и-docker-compose-в-ubuntu-вм-virtualbox) ниже.

Terraform — см. [подготовку к занятию 10](lesson10/README.md#подготовка) (ставится внутрь ВМ). SSH-ключ для GitHub создавайте **внутри ВМ**.

> **В браузере Windows** сервисы ВМ открываются по проброшенным портам: `http://localhost:8000`, nginx — `http://localhost:8080`.
> **Если ВМ не стартует** с ошибкой про VT-x/AMD-V — включите виртуализацию в BIOS. Если VirtualBox работает очень медленно (черепаха в строке состояния) — отключите Hyper-V: PowerShell от администратора `bcdedit /set hypervisorlaunchtype off` и перезагрузка (Docker Desktop и WSL после этого работать не будут — для курса они не нужны).

### macOS

Нужен [Homebrew](https://brew.sh).
```bash
brew install git ansible git-filter-repo
```
Docker и Docker Compose — см. раздел [Docker на macOS](#docker-и-docker-compose-на-macos) ниже.
Terraform — см. [подготовку к занятию 10](lesson10/README.md#подготовка).

### Docker и Docker Compose в Ubuntu (ВМ VirtualBox)

Ставим **Docker Engine** из официального репозитория Docker. Compose идёт плагином — команда `docker compose` (через пробел). Все команды — внутри ВМ.

1. Удалите старые/неофициальные пакеты, если они есть (ошибки «not installed» — это нормально):
   ```bash
   for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
     sudo apt-get remove -y $pkg
   done
   ```
2. Подключите репозиторий Docker:
   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc

   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
   https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```
3. Установите Docker Engine, Buildx и Compose:
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```
4. Разрешите запускать docker без `sudo` и включите автозапуск:
   ```bash
   sudo usermod -aG docker $USER
   sudo systemctl enable --now docker
   exit            # выйдите из SSH и подключитесь снова — иначе группа не применится
   ```
5. Проверка (после повторного входа):
   ```bash
   docker version
   docker compose version        # Docker Compose version v2.x или новее
   docker run --rm hello-world   # «Hello from Docker!»
   ```
6. **Скачайте образы курса из нашего реестра** — см. раздел [Образы курса из GHCR](#образы-курса-из-нашего-реестра-ghcr). Docker Hub из России работает нестабильно.

> Короткий путь для тех, кто торопится: `curl -fsSL https://get.docker.com | sudo sh` — официальный скрипт делает шаги 1–3 сам. Шаги 4 и 6 всё равно нужны.

### Docker и Docker Compose на macOS

На Mac ставим **Docker Desktop** — в него уже входят Docker Engine, Compose и Buildx.

1. Узнайте процессор: меню Apple → «Об этом Mac». **Apple M1/M2/M3/M4** → версия *Apple Silicon*, **Intel** → версия *Intel chip*.
2. Установите одним из способов:
   - скачайте `.dmg` с https://docs.docker.com/desktop/setup/install/mac-install/ и перетащите Docker в «Программы»;
   - или через Homebrew: `brew install --cask docker`
3. Запустите **Docker** из «Программ», примите соглашение и дождитесь зелёного статуса *Engine running* (значок кита в строке меню).
4. Рекомендуемые настройки: **Settings → Resources** — CPU 2+, Memory 4 ГБ+; **Settings → General** — включить *Start Docker Desktop when you sign in* (по желанию).
5. Проверка в терминале:
   ```bash
   docker version
   docker compose version
   docker run --rm hello-world
   ```
6. **Скачайте образы курса из нашего реестра** — см. раздел [Образы курса из GHCR](#образы-курса-из-нашего-реестра-ghcr).

> На Mac с Apple Silicon все образы курса (`postgres`, `redis`, `nginx`, `python`) есть в версии arm64 — ничего дополнительно настраивать не нужно.

### Образы курса из нашего реестра (GHCR)

Docker Hub из России работает нестабильно, поэтому все базовые образы курса скопированы в **GitHub Container Registry** этого репозитория (`ghcr.io/tenroman1-design/devops-lab/...`). Их обновляет workflow `mirror-images` раз в месяц; образы собраны для amd64 (ВМ) и arm64 (Mac на M1–M4).

| Привычное имя | Копия в нашем реестре |
|---|---|
| `postgres:17-alpine` | `ghcr.io/tenroman1-design/devops-lab/postgres:17-alpine` |
| `redis:7-alpine` | `ghcr.io/tenroman1-design/devops-lab/redis:7-alpine` |
| `python:3.12-slim` | `ghcr.io/tenroman1-design/devops-lab/python:3.12-slim` |
| `nginx:1.27-alpine` | `ghcr.io/tenroman1-design/devops-lab/nginx:1.27-alpine` |
| `hello-world:latest` | `ghcr.io/tenroman1-design/devops-lab/hello-world:latest` |
| `zricethezav/gitleaks:latest` | `ghcr.io/tenroman1-design/devops-lab/gitleaks:latest` |

**Скачать всё одной командой** — скрипт скачает образы из GHCR и даст им привычные имена, поэтому `docker-compose.yml` и `Dockerfile` работают без изменений:
```bash
git clone https://github.com/tenroman1-design/devops-lab.git && cd devops-lab
bash scripts/pull-images.sh
```
Без клонирования репозитория:
```bash
curl -fsSL https://raw.githubusercontent.com/tenroman1-design/devops-lab/main/scripts/pull-images.sh | bash
```
Вручную, для одного образа:
```bash
docker pull ghcr.io/tenroman1-design/devops-lab/postgres:17-alpine
docker tag  ghcr.io/tenroman1-design/devops-lab/postgres:17-alpine postgres:17-alpine
```
Логин в GHCR не нужен — пакеты публичные.

### Зеркала Docker Hub (запасной вариант)

Если нужен образ, которого нет в нашем реестре, а `docker pull` зависает на `Waiting` / `Pulling fs layer` или падает с `TLS handshake timeout`, `403`, `toomanyrequests` — подключите зеркала Docker Hub. Docker перебирает их по порядку и только в конце идёт в сам Docker Hub.

| Зеркало | Кто поддерживает |
|---|---|
| `https://dh-mirror.gitverse.ru` | GitVerse (СберТех) |
| `https://dockerhub.timeweb.cloud` | Timeweb Cloud |
| `https://dockerhub1.beget.com` | Beget |
| `https://mirror.gcr.io` | Google |

**Ubuntu (ВМ):**
```bash
cat <<'EOF' | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://dh-mirror.gitverse.ru",
    "https://dockerhub.timeweb.cloud",
    "https://dockerhub1.beget.com",
    "https://mirror.gcr.io"
  ],
  "max-concurrent-downloads": 3
}
EOF
sudo systemctl restart docker
docker info | grep -A4 "Registry Mirrors"     # должны быть видны все четыре
docker pull hello-world
```

**macOS:** Docker Desktop → **Settings → Docker Engine** → добавьте в JSON ключ `registry-mirrors` с тем же списком (остальные ключи, которые там уже есть, не удаляйте) → **Apply & restart**.

**Если какой-то образ всё равно не качается** — скачайте его напрямую с зеркала и дайте привычное имя:
```bash
docker pull dh-mirror.gitverse.ru/library/postgres:17-alpine          # официальные образы — через library/
docker tag  dh-mirror.gitverse.ru/library/postgres:17-alpine postgres:17-alpine

docker pull dh-mirror.gitverse.ru/zricethezav/gitleaks:latest         # образы пользователей — как есть
docker tag  dh-mirror.gitverse.ru/zricethezav/gitleaks:latest zricethezav/gitleaks:latest
```
Прерывайте зависший pull через **Ctrl+C**, а не Ctrl+Z (Ctrl+Z только ставит процесс на паузу). Уже скачанные слои при повторе заново не качаются.

> Зеркала поддерживают сторонние компании, и любое из них может перестать работать — поэтому в списке их несколько. Если недоступны все, преподаватель раздаст образы архивом: `docker load -i images.tar`.

### Terraform (для всех)

Terraform нужен на занятии 10. Установка и подготовка расписаны в [README занятия 10 → «Подготовка»](lesson10/README.md#подготовка). Поставьте его заранее, дома.

### Git, GitHub и SSH-ключ (для всех)

```bash
git config --global user.name  "Имя Фамилия"
git config --global user.email "you@edu.hse.ru"
ssh-keygen -t ed25519 -C "you@edu.hse.ru"     # Enter на все вопросы
cat ~/.ssh/id_ed25519.pub                     # скопировать → GitHub: Settings → SSH and GPG keys → New SSH key
ssh -T git@github.com                         # «Hi <login>! You've successfully authenticated»
```

### Скачайте образы заранее

Чтобы не ждать сеть в аудитории — из нашего реестра (см. [Образы курса из GHCR](#образы-курса-из-нашего-реестра-ghcr)):
```bash
bash scripts/pull-images.sh
```

### Финальная проверка

```bash
docker compose version && git --version && terraform -version && git filter-repo --version
git clone https://github.com/tenroman1-design/devops-lab.git && cd devops-lab
bash scripts/pull-images.sh
```
Все команды отработали без ошибок — вы готовы. Если нет — напишите в чат группы текст ошибки и свою ОС.

---

## Занятия

У каждого занятия свой README: подготовка к занятию, шаги практики, частые ошибки и **домашнее задание**.

| Занятие | Тема | README |
|---|---|---|
| 8 | Docker Compose: сети, тома, масштабирование | [lesson08/README.md](lesson08/README.md) · [шаблон ДЗ](lesson08/HOMEWORK.md) |
| 9 | Nginx перед бэкендом, конфигурация и секреты | [lesson09/README.md](lesson09/README.md) · [шаблон ДЗ](lesson09/HOMEWORK.md) |
| 10 | Infrastructure as Code: своя ВМ в cloud.ru через Terraform | [lesson10/README.md](lesson10/README.md) · [шаблон ДЗ](lesson10/HOMEWORK.md) |
| 11 | Terraform как проект: модули, for_each, state в облаке | [lesson11/README.md](lesson11/README.md) · [шаблон ДЗ](lesson11/HOMEWORK.md) |
| 12 | Кластер в облаке: балансировщик, приватная сеть, отказоустойчивость | [lesson12/README.md](lesson12/README.md) · [шаблон ДЗ](lesson12/HOMEWORK.md) |

**Как сдавать ДЗ:** в папке каждого занятия лежит шаблон `HOMEWORK.md`. Скопируйте его, назовите `ДЗ-<номер>-<фамилия>.md` (например, `ДЗ-08-ivanov.md`), заполните и отправьте **файлом в чат группы** до начала следующего занятия. Вывод команд — текстом, без скриншотов. Пароли и ключи в ДЗ не вставляйте никогда.

> ⛔ С занятия 10 у вас появляются ресурсы в облаке. Закончили работу — **`terraform destroy`** в тот же день. ВМ не оставляем включённой, подробности — в [README занятия 10](lesson10/README.md).

---

## Если что-то не работает

Здесь — общие проблемы с Docker. Ошибки конкретного занятия описаны в его README.

Первое действие всегда: `docker compose ps` → `docker compose logs <сервис>`.

| Симптом | Причина | Решение |
|---|---|---|
| `Cannot connect to the Docker daemon` / `permission denied` на docker.sock | Docker не запущен / пользователь не в группе docker | macOS: запустить Docker Desktop; ВМ: `sudo usermod -aG docker $USER` и перелогиниться |
| Windows: `localhost:8000` не открывается | Нет проброса порта в VirtualBox | Настроить → Сеть → Проброс портов |
| `port is already allocated` | Порт занят другим контейнером | `docker ps`, остановить лишнее или сменить порт |
| backend: `Connection refused` к БД | `localhost` вместо имени сервиса | В URL должно быть `db`, не `localhost` |
| `pull` висит на `Waiting` / TLS handshake timeout / 403 / toomanyrequests | Нет доступа к Docker Hub | [Образы из GHCR](#образы-курса-из-нашего-реестра-ghcr) или [зеркала](#зеркала-docker-hub-запасной-вариант) |
| `pull` висит на `Waiting` на всех слоях сразу, даже после перезапуска | Остались процессы `docker pull`, остановленные через Ctrl+Z, и недокачанные куски | `pkill -9 -f "docker pull"`; `sudo systemctl stop docker docker.socket containerd`; `sudo rm -rf /var/lib/containerd/io.containerd.content.v1.content/ingest/*`; `sudo systemctl start containerd docker` |
| `password authentication failed` | Том создан со старым паролем | `docker compose down -v` (данные удалятся) |

## Не забудьте

Облачные ресурсы тарифицируются, пока существуют. **После каждой работы с облаком** — на занятии и дома — удаляйте всё, что создали, в каждой папке, где делали `apply`:
```bash
cd lesson10/practice && terraform destroy && terraform state list   # пусто
cd ../hw            && terraform destroy && terraform state list   # если делали ДЗ
```
То же — в `lesson11/practice`, `lesson11/hw`, `lesson12/practice`, `lesson12/hw`. С занятия 11 state лежит в бакете, поэтому `destroy` можно сделать с любого ноутбука команды.
Остановить ВМ в консоли недостаточно: за диск и публичный IP облако продолжает брать деньги.
