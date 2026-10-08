# Занятие 11. Terraform как проект: модули, for_each и state в облаке

На занятии 10 вся инфраструктура жила в одном файле, а state — на ноутбуке. Для одной ВМ и одного человека этого хватает. Но как только серверов несколько, а над кодом работает команда, нужно три вещи:

1. **Модуль** — описать «сервер» один раз и вызывать его как функцию.
2. **`for_each`** — создать N серверов одной картой, а не копипастой.
3. **Удалённый state** — хранить state в облаке, чтобы вся команда видела одну и ту же картину.

```
                       ┌──────────── practice/ (корневой модуль) ────────────┐
var.servers = {        │  data: образ, подсеть      resource: firewall, ключ  │
  web-1 = {}     ──▶   │  module "web" (for_each) ──▶ ../modules/vm  × N      │
  web-2 = {}           └──────────────────────────────┬──────────────────────┘
}                                                     │ state
                                                      ▼
                                  бакет OBS: <prefix>/lesson11.tfstate
```

## Подготовка

- [ ] Занятие 10 пройдено: Terraform установлен, `~/.terraformrc` настроен, SSH-ключ есть ([подготовка занятия 10](../lesson10/README.md#подготовка)).
- [ ] После занятия 10 вы сделали `terraform destroy` — проверьте: `cd lesson10/practice && terraform state list` → пусто.
- [ ] Обновите репозиторий:
  ```bash
  cd devops-lab && git pull
  ls lesson11        # README.md  HOMEWORK.md  modules  practice  solution
  ```
- [ ] Найдите напарника: часть 4 делается в паре.

Ключи доступа преподаватель даст на занятии, как и в прошлый раз. Для state в облаке понадобятся **те же ключи**, но под другими именами (об этом в части 3).

## Практика

### Часть 1. Модуль: читаем и вызываем (20 мин)

Модуль — это просто папка с `.tf`-файлами. У него есть **входы** (`variable`), **выходы** (`output`) и ресурсы внутри.

```bash
cd lesson11
cat modules/vm/variables.tf     # входы: name, image_id, flavor, subnet_id, key_pair, public_ip…
cat modules/vm/main.tf          # ВМ + публичный IP (EIP) — тот же код, что в занятии 10
cat modules/vm/outputs.tf       # выходы: id, name, private_ip, public_ip
```

Обратите внимание на `count = var.public_ip ? 1 : 0` в `modules/vm/main.tf`. Так в Terraform делают ресурс «по условию»: 1 копия или ни одной. Пригодится на занятии 12, где у серверов не будет публичных IP.

Теперь вызываем модуль:

```bash
cd practice
export SBC_ACCESS_KEY="…"  SBC_SECRET_KEY="…"      # ключи от преподавателя
cp terraform.tfvars.example terraform.tfvars        # впишите свой prefix
grep -n TODO main.tf                                # три TODO в блоке module "web"
```

Замените три `TODO` в `main.tf`:

| TODO | Что подставить | Подсказка |
|---|---|---|
| `source` | путь к папке модуля | относительно папки `practice` |
| `subnet_id` | ID общей подсети | её уже читает `data "sbercloud_vpc_subnet" "course"` выше |
| `key_pair` | **имя** ключа | ресурс `sbercloud_kps_keypair.key` выше |

```bash
terraform init          # скачает провайдер и «подключит» модуль: "- web in ../modules/vm"
terraform plan          # Plan: 7 to add (firewall + 2 правила + ключ + ВМ, EIP, привязка)
terraform apply
curl $(terraform output -raw url)       # «Я — <prefix>-web-1» (через 1–2 мин)
terraform state list                     # module.web.sbercloud_compute_instance.this — адрес ресурса внутри модуля
```

> Модуль не знает, откуда взялись образ и подсеть: их передаёт вызывающий код. Поэтому один и тот же модуль работает и с публичными серверами (сегодня), и с приватными (занятие 12).

### Часть 2. for_each: N серверов одной картой (20 мин)

В `variables.tf` уже есть переменная `servers` — карта «имя сервера → настройки»:

```hcl
default = {
  "web-1" = {}
  "web-2" = {}
}
```

**1. Превращаем один вызов модуля в N.** В `main.tf`, в блоке `module "web"`:

```hcl
module "web" {
  source   = "../modules/vm"
  for_each = var.servers                                  # ← добавить

  name = "${var.prefix}-${each.key}"                      # ← было "${var.prefix}-web-1"
  ...
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    name = "${var.prefix}-${each.key}"                    # ← и здесь
  })
}
```

В `outputs.tf` закомментируйте выходы части 1 и раскомментируйте выходы части 2 (с `for`).

**2. Смотрим план — и пугаемся.**

```bash
terraform plan
```

План хочет **удалить** `module.web` и создать `module.web["web-1"]` и `module.web["web-2"]`. Почему? У ресурса сменился **адрес** в state: был `module.web`, стал `module.web["web-1"]`. Terraform думает, что это разные серверы.

**3. Говорим Terraform, что это переезд.** Раскомментируйте в конце `main.tf` блок `moved`:

```hcl
moved {
  from = module.web
  to   = module.web["web-1"]
}
```

```bash
terraform plan      # web-1: "has moved to module.web["web-1"]", добавляется только web-2
terraform apply
terraform output    # public_ips = { "web-1" = "…", "web-2" = "…" }
```

**4. Добавляем и убираем серверы.** В `terraform.tfvars`:

```hcl
servers = {
  "web-1" = {}
  "web-2" = {}
  "web-3" = {}
}
```

`terraform plan` покажет `+` только для web-3. Теперь уберите строку `"web-2" = {}` и снова выполните `terraform plan`: удаляется **ровно web-2**, web-1 и web-3 не трогаются. Примените нужный вариант, но оставьте не больше двух серверов: квоты общие.

> **Почему не `count`?** С `count` серверы адресуются по номеру: `[0]`, `[1]`, `[2]`. Пусть имена берутся из списка `["web-1", "web-2", "web-3"]`. Уберите из списка `web-2` — номера «сдвинутся»: сервер `[1]` получит настройки web-3 и изменится, хотя его не трогали, а `[2]` (настоящий web-3) будет удалён. У `for_each` адрес — имя (`["web-3"]`), оно не сдвигается.

### Часть 3. State в облаке (15 мин)

Сейчас state — файл `terraform.tfstate` на вашем ноутбуке. Его не видит напарник, его можно потерять вместе с ноутбуком, его нельзя класть в Git (в нём IP, ID и иногда секреты). Решение — **backend**: хранилище state вне ноутбука. В cloud.ru это бакет **OBS** — объектное хранилище, совместимое с Amazon S3.

```bash
cat backend.tf.example
cp backend.tf.example backend.tf
```

Бакет `hse-devops-tfstate` заранее создал преподаватель. Если он назовёт другое имя — поправьте `bucket` в `backend.tf`.

Backend на протоколе S3 ищет ключи в переменных `AWS_*`. Это те же ключи cloud.ru:

```bash
export AWS_ACCESS_KEY_ID="$SBC_ACCESS_KEY"  AWS_SECRET_ACCESS_KEY="$SBC_SECRET_KEY"

# в блоке backend нельзя использовать переменные — свой путь к state передаём при init:
terraform init -migrate-state -backend-config="key=<prefix>/lesson11.tfstate"
#   Do you want to copy existing state to the new backend? → yes
```

Проверяем:

```bash
terraform state list        # те же ресурсы — state теперь читается из облака
terraform plan              # No changes
cat terraform.tfstate       # пустой файл: локальная копия больше не используется
rm terraform.tfstate terraform.tfstate.backup
```

В консоли cloud.ru откройте **Object Storage Service → бакет → папка с вашим префиксом**. Там лежит `lesson11.tfstate`.

> **Блокировки нет.** Если двое одновременно сделают `apply` в один state, кто-то из них перезапишет изменения другого. В Amazon блокировку делает отдельная таблица DynamoDB. У нас её нет, поэтому правило команды: **`apply` запускает один человек**, остальные смотрят `plan`.

### Часть 4. Работа в паре: чужой state (10 мин)

Вы с напарником — два «инженера», которые хотят посмотреть на инфраструктуру друг друга. Только `plan`, **никаких `apply`!**

```bash
cd ..                                   # из practice в lesson11
cp -r practice practice-partner
cd practice-partner
rm -rf .terraform terraform.tfstate*    # отвязываемся от своего state
terraform init -backend-config="key=<prefix-напарника>/lesson11.tfstate"
terraform state list                    # серверы напарника!
terraform plan
```

План, скорее всего, **не пустой**. Ищите причину в плане:
- другой `prefix` в вашем `terraform.tfvars` → Terraform хочет переименовать все ресурсы;
- другой публичный ключ в `~/.ssh/id_ed25519.pub` → ключевая пара `-/+`;
- другая карта `servers`.

Поставьте в `terraform.tfvars` префикс напарника — план станет короче. Вывод: инфраструктуру описывают **код + переменные + state** вместе. Код лежит в Git, state в бакете, а переменные команда тоже должна хранить общими, а не у каждого свои.

```bash
cd .. && rm -rf practice-partner        # чужой state больше не нужен
```

### Часть 5. Уборка (5 мин)

```bash
cd practice
terraform destroy
terraform state list       # пусто
```

Файл state в бакете **остаётся**, но он пустой. Так и должно быть: при следующем `apply` Terraform продолжит с него.

### Задания для тех, кто закончил раньше

1. Добавьте в модуль вход `flavor` со значением по умолчанию и сделайте у одного сервера в `servers` другой тип ВМ. Карта в `servers` для этого должна уметь хранить `flavor`.
2. Выведите output `servers`: карта «имя → { ip, url }» одним for-выражением.
3. Посмотрите state из облака напрямую: `terraform state pull | head -30`. Найдите там ресурсы модуля.

## Если что-то не работает

| Симптом | Причина | Решение |
|---|---|---|
| `Module not installed` | Добавили или изменили модуль без init | `terraform init` |
| `Unreadable module directory` / `source` не найден | Неверный путь в `source` | `source = "../modules/vm"` — путь от папки `practice` |
| `Invalid reference` в `subnet_id`/`key_pair` | Пропущена часть адреса | `data.<тип>.<имя>.id`, `<тип>.<имя>.name` |
| План хочет удалить web-1 после `for_each` | Сменился адрес ресурса | Блок `moved` из части 2 |
| `No valid credential sources found` / `InvalidAccessKeyId` при init | Не заданы `AWS_*` | `export AWS_ACCESS_KEY_ID="$SBC_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SBC_SECRET_KEY"` |
| `NoSuchBucket` | Неверное имя бакета | Имя — у преподавателя, поправьте `bucket` в `backend.tf` |
| `Backend configuration changed` | Поменяли `backend.tf` или `key` | `terraform init -reconfigure -backend-config="key=…"` |
| `AccessDenied` при init | У ключей нет прав на OBS | Сообщите преподавателю |

## ⛔ Главное правило: ресурсы не оставляем

Всё как на занятии 10. Каждый сервер — это ВМ и **публичный IP**, оба стоят денег, пока существуют. В конце занятия и каждой сессии ДЗ:

```bash
terraform destroy
terraform state list       # пусто
```

## Домашнее задание

**Срок — до занятия 12.** Как сдавать: заполните шаблон [HOMEWORK.md](HOMEWORK.md) (скопируйте, назовите `ДЗ-11-фамилия.md`) и отправьте файлом в чат группы.

Работайте в копии: `cp -r practice hw && cd hw && rm -rf .terraform terraform.tfstate*`. Префикс — **`<фамилия>-hw`**, state — **отдельный**:

```bash
terraform init -reconfigure -backend-config="key=<фамилия>-hw/hw11.tfstate"
```

1. **Свой модуль firewall.** Вынесите группу безопасности в модуль `lesson11/modules/firewall`:
   - входы `name` (строка) и `ports` (список чисел);
   - внутри — группа безопасности и правила через `for_each` по портам;
   - выход `id`.

   Подключите его в `hw/main.tf` вместо ресурсов `sbercloud_networking_secgroup*`. Порты — `[22, 80]`.

   **Цель — переезд без пересоздания:** добавьте блоки `moved`, чтобы `terraform plan` после рефакторинга показал `0 to add, 0 to change, 0 to destroy`. Подсказка: адрес правила внутри модуля выглядит так: `module.firewall.sbercloud_networking_secgroup_rule.this["22"]`.
2. **Три сервера.** Задайте `servers` из трёх серверов, у одного `disk_size = 20`. Сделайте `apply`. Затем удалите из карты средний сервер и сохраните **итоговую строку** `terraform plan` (`Plan: …`). Что удаляется и что нет?
3. **State в облаке.** Приложите вывод `terraform state list` и путь к вашему state в бакете.
4. **Вопросы (письменно, коротко):**
   - Чем `for_each` лучше `count` для серверов? Что случится с `count`, если удалить средний элемент?
   - Почему в блоке `backend` нельзя использовать переменные и как мы обошли это ограничение?
   - Что может случиться, если два человека одновременно сделают `apply` в один state? Как от этого защищаются?
   - Зачем нужен блок `moved`?
5. ⛔ **Уборка:** `terraform destroy` и пустой `terraform state list`. Без этого ДЗ не принимается.

**Что сдать** — всё по шаблону [HOMEWORK.md](HOMEWORK.md): код модуля `firewall`, вызов модуля и блоки `moved`, выводы команд, ответы и вывод `destroy`. **Без** `terraform.tfvars`, `terraform.tfstate` и ключей.
