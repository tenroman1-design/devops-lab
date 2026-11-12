# Практическое занятие: деплой Nginx reverse proxy с помощью Ansible

### Предмет: DevOps
Тема: Использование Ansible для деплоя веб-сервера Nginx на виртуальную машину
Формат: практическая работа
Продолжительность: 90–120 минут
#### 1. Цель занятия
После выполнения практической работы студент должен уметь:
- подключаться к удалённой VM по SSH с помощью Ansible;
- создавать inventory;
- писать Ansible Playbook без использования ролей;
- устанавливать Nginx;
- управлять конфигурацией Nginx через Ansible;
- проверять конфигурацию перед применением;
- запускать и включать Nginx в автозагрузку;
- использовать Nginx как reverse proxy;
- проксировать запросы с публичного IP VM на Docker-сервис, работающий на localhost:80;
- проверять результат через HTTP.
#### 2. Исходная инфраструктура
Предполагается, что Terraform уже создал виртуальную машину.

У каждого студента есть:
```
                    Internet
                       |
                       | HTTP :80
                       v
              +-------------------+
              |   Virtual Machine |
              |                   |
              |  Public IP        |
              |       |           |
              |       v           |
              |    Nginx :80      |
              |       |           |
              |       | reverse   |
              |       | proxy     |
              |       v           |
              |  Docker service   |
              |    localhost:80    |
              +-------------------+
                       |
                       v
                 Web application
```

На VM уже установлены:
- Docker;
- SSH;
- SSH-ключ;
- операционная система.
Допустим, Docker-контейнер уже запущен и приложение доступно на:
```
http://127.0.0.1:80
```

То есть до установки Nginx студент может проверить:
```
curl http://127.0.0.1:80
```
### Важное замечание: нужно переписать конфиг скрипта cloud-init для того, чтобы адрес прослушки приложения в docker сменился с **0.0.0.0** на **127.0.0.1**
Ожидаемый результат — ответ от Docker-приложения.
#### 3. Почему здесь нужен Nginx
Может показаться, что Nginx не нужен:
Internet → Docker :80

Но в реальной инфраструктуре Nginx часто используется как внешний reverse proxy:
Internet
   |
   | :80
   v
Nginx
   |
   | proxy_pass
   v
Docker application
   |
   | :80
   v
Application

Это позволяет в дальнейшем:
- добавить HTTPS;
- установить TLS-сертификаты;
- настроить несколько backend-сервисов;
- добавить HTTP-заголовки;
- реализовать балансировку;
- ограничить доступ;
- организовать централизованную обработку HTTP-запросов.
#### 4. Структура проекта
Необходимо создать следующий проект:
```
ansible-nginx/
├── inventory.ini
├── ansible.cfg
└── nginx.yml
```
Ролей здесь нет.


#### 5. Подготовка Ansible
На рабочем компьютере студента:
```
mkdir ansible-nginx
cd ansible-nginx
```
Создаём:
```
touch inventory.ini
touch ansible.cfg
touch nginx.yml
```
#### 6. Настройка inventory
В inventory.ini указываем IP виртуальной машины.

Например:
```
[web]
web01 ansible_host=203.0.113.10 ansible_user=student
```
Здесь:
- web — группа серверов;
- web01 — имя сервера;
- ansible_host — публичный IP VM;
- ansible_user — пользователь Linux, под которым разрешён SSH-доступ.
Если Terraform выдаёт студенту IP, например:
```
51.123.45.67
```
то:
```
[web]
web01 ansible_host=51.123.45.67 ansible_user=student
```
#### 7. SSH-ключ
Если Terraform создал SSH-ключ в стандартном месте, Ansible может использовать его автоматически.

Если ключ находится, например, здесь:
```
~/.ssh/devops_student
```
можно явно указать его:
```
[web]
web01 ansible_host=51.123.45.67 ansible_user=student ansible_ssh_private_key_file=~/.ssh/devops_student
```
Важный момент:

приватный SSH-ключ не должен попадать в Git-репозиторий.
#### 8. Настройка ansible.cfg
Создаём:
```
[defaults]
inventory = ./inventory.ini
host_key_checking = False
interpreter_python = auto_silent

host_key_checking = False это удобно для учебного стенда, где VM может пересоздаваться Terraform.
```
В production такой параметр следует использовать осознанно, поскольку проверка SSH host key является частью защиты соединения.
#### 9. Проверяем SSH через Ansible
До написания Playbook студент должен убедиться, что Ansible вообще видит сервер.

Команда:
```
ansible all -m ping
```
Ожидаемый результат:
```
web01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Если ping не работает, не нужно переходить к Playbook.

Студент должен сначала разобраться с:
- IP;
- SSH;
- пользователем;
- ключом;
- security group/firewall;
- доступностью VM.
#### 10. Проверяем Docker
До установки Nginx проверим существующее приложение.

Подключиться:
```
ssh student@51.123.45.67
```
Проверить Docker:
```
docker ps
```
И проверить приложение:
```
curl http://127.0.0.1:80
```
Например, приложение может вернуть:
```
Hello from Docker application!
```
Важно, чтобы студент понял:
```
127.0.0.1:80
```
— это локальный сервис на VM, а не порт Docker на компьютере студента.
#### 11. Первый Playbook
Теперь создаём nginx.yml.

Начнём с минимального варианта:
```
---
- name: Install and configure Nginx
  hosts: web
  become: true

  tasks:

    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    - name: Start nginx
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
```

Запуск:
ansible-playbook nginx.yml

После выполнения:
```
curl http://51.123.45.67
```
Пока Nginx будет отдавать собственную страницу.

#### 12. Что означает become
Обратите внимание:
```
become: true
```
Студент подключается по SSH обычным пользователем:

student

но установка пакета требует root:
```
student
   |
   | sudo
   v
root
```
Ansible использует механизм privilege escalation:
```
become: true
```
Аналог вручную:
```
sudo apt install nginx
```
#### 13. Настраиваем reverse proxy
Теперь основная часть практической работы.

Нам нужно получить:
```
Internet
   |
   | HTTP :80
   v
Nginx
   |
   | http://127.0.0.1:80
   v
Docker
```
Создадим конфигурацию Nginx непосредственно через Ansible.

В Playbook добавляем задачу:
```
    - name: Configure nginx reverse proxy
      ansible.builtin.copy:
        dest: /etc/nginx/sites-available/docker-app
        owner: root
        group: root
        mode: '0644'
        content: |
          server {
              listen 80;
              server_name _;

              location / {
                  proxy_pass http://127.0.0.1:80;

                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              }
          }
      notify: Restart nginx
```
Здесь есть важный момент:
```
proxy_pass http://127.0.0.1:80;
```
Nginx получает запрос:
```
GET /
```
и передаёт его локальному приложению:
http://127.0.0.1:80

#### 14. Почему используем notify
Вместо того чтобы всегда перезапускать Nginx:
```
service:
  state: restarted
```
используем:
```
notify: Restart nginx
```
Это означает:
Перезапусти Nginx только если конфигурационный файл изменился.

В конце Playbook добавляем:
```
  handlers:

    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
```
Это один из важных принципов Ansible:

изменение конфигурации → handler → перезапуск сервиса.

#### 15. Полный Playbook
В итоге у студента должен получиться следующий nginx.yml:
```
---
- name: Deploy Nginx reverse proxy
  hosts: web
  become: true

  tasks:

    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    - name: Configure nginx reverse proxy
      ansible.builtin.copy:
        dest: /etc/nginx/sites-available/docker-app
        owner: root
        group: root
        mode: '0644'
        content: |
          server {
              listen 80;
              server_name _;

              location / {
                  proxy_pass http://127.0.0.1:80;

                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              }
          }
      notify: Restart nginx

    - name: Enable nginx site
      ansible.builtin.file:
        src: /etc/nginx/sites-available/docker-app
        dest: /etc/nginx/sites-enabled/docker-app
        state: link
      notify: Restart nginx

    - name: Disable default nginx site
      ansible.builtin.file:
        path: /etc/nginx/sites-enabled/default
        state: absent
      notify: Restart nginx

    - name: Check nginx configuration
      ansible.builtin.command:
        cmd: nginx -t
      changed_when: false

    - name: Ensure nginx is running
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

  handlers:

    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
```

#### 16. Запуск Playbook
Запускаем:
```
ansible-playbook nginx.yml
```

Студент должен обратить внимание на результат:
```
TASK [Install nginx]
changed: [web01]

TASK [Configure nginx reverse proxy]
changed: [web01]

TASK [Enable nginx site]
changed: [web01]

TASK [Disable default nginx site]
changed: [web01]

TASK [Check nginx configuration]
ok: [web01]

TASK [Ensure nginx is running]
ok: [web01]

RUNNING HANDLER [Restart nginx]
changed: [web01]
```

#### 17. Проверяем результат
Теперь запрос отправляется уже не непосредственно к Docker, а к Nginx:
```
curl http://51.123.45.67/
```

Но ответ должен прийти от Docker-приложения.

Получается:
```
curl
  |
  | HTTP :80
  v
Public IP
  |
  v
Nginx
  |
  | proxy_pass
  v
127.0.0.1:80
  |
  v
Docker
  |
  v
Application
```

#### 18. 
Почему нельзя просто написать?

proxy_pass http://127.0.0.1:80;

и оставить всё остальное?

Можно.

Минимальная конфигурация действительно может выглядеть так:
```
server {
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:80;
    }
}
```

Но дополнительные заголовки:
```
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

позволяют backend-приложению понимать:
- какой Host запросил клиент;
- какой IP был у клиента;
- через какие proxy прошёл запрос;
- какой первоначальный протокол использовал клиент.
Это особенно важно, когда дальше появляется HTTPS и несколько proxy.

#### 19. Идемпотентность
Теперь студент должен выполнить:
ansible-playbook nginx.yml

второй раз.

В идеальном случае большинство задач должны показать:
```
ok: [web01]
```

а не:
```
changed: [web01]
```

Это демонстрирует один из главных принципов Ansible:
Playbook должен описывать желаемое состояние инфраструктуры, а не последовательность ручных команд.

Например:
state: present

означает:
Nginx должен быть установлен.

а не:
Выполни команду установки Nginx.

#### 20. Проверяем идемпотентность
После второго запуска студент должен увидеть примерно:
```
TASK [Install nginx]
ok: [web01]

TASK [Configure nginx reverse proxy]
ok: [web01]

TASK [Enable nginx site]
ok: [web01]

TASK [Disable default nginx site]
ok: [web01]

TASK [Check nginx configuration]
ok: [web01]

TASK [Ensure nginx is running]
ok: [web01]
```

И:
```
changed=0
```

Это хороший критерий выполнения задания.


#### Задание №1
Изменить конфигурацию так, чтобы Nginx передавал backend следующий заголовок:
X-Student-Name

со значением своего имени.

Например:
```
proxy_set_header X-Student-Name "Ivan Ivanov";
```

Проверить наличие заголовка на backend.
#### Задание №2
Добавить отдельный endpoint:
/health

который отвечает непосредственно Nginx:
OK

То есть:
http://PUBLIC_IP/health

должен возвращать:
OK

а остальные запросы:
http://PUBLIC_IP/

должны отправляться в Docker.

Подсказка:
```
location /health {
    ...
}

location / {
    ...
}
```

####Задание №3
Добавить проверку конфигурации перед перезапуском Nginx.

Студент должен добиться логики:
изменение config
       |
       v
nginx -t
       |
       | успешно
       v
restart nginx

При этом некорректная конфигурация не должна приводить к перезапуску Nginx.

#### 22. Контрольные вопросы
1. Чем Ansible отличается от Terraform?
терраформ настраивает инфраструктуру машины, ансибл настраивает ее внутренности
2. Зачем нужен inventory?
перечисление серверов которые должен настроить ансибл
3. Что делает become: true?
дает рут права
4. Что такое идемпотентность?
одно на вход -> одно на выход
5. Чем command отличается от специализированного Ansible-модуля?
комманд запускает команду вслепую, а модуль отслеживает состояния машины
6. Зачем нужен handler?
команды которые выполняются в конце если в процессе их запросили
7. Когда выполняется notify?
когда произошли изменения (changed)
8. Зачем проверять nginx -t?
чтобы убедится в работоспособности nginx
9. Что делает proxy_pass?
куда отправить пропущенные пакеты
10. Почему Docker-приложение можно оставить доступным только на 127.0.0.1:80?
это внутренний порт, извне не попасть без прокси
11. В чём преимущество схемы Internet → Nginx → Application перед: Internet → Application
балансировка, фильтрация (в тч на тех страницы типа хелсчека)
12. Что произойдёт, если Docker-приложение остановить?
502 bad gateway

#### 23. Финальная архитектура
В результате практической работы студент должен получить

получилось немного другое, тк там еще в докере нгинх висит как балансировщик, т.е. там два раза его проходит, тк я использовал машину с 12 урока которая берет докеркомпоз с 9, и поменял лишь входной порт на внутренний, но если рассматривать апп как совокупность контейнеров то суть та же


```
                     Internet
                        |
                        | HTTP :80
                        |
                        v
              +-------------------+
              |       VM          |
              |                   |
              |  Public IP        |
              |       |           |
              |       v           |
              |   +-------+       |
              |   | Nginx |       |
              |   +---+---+       |
              |       |           |
              |       | proxy     |
              |       v           |
              |  127.0.0.1:80    |
              |       |           |
              |       v           |
              |   +---------+     |
              |   | Docker  |     |
              |   |  App    |     |
              |   +---------+     |
              +-------------------+
```

При этом Terraform отвечает за создание инфраструктуры, а Ansible — за конфигурацию и состояние сервера:
```
Terraform
   |
   | VM + IP + SSH + Docker
   v
Virtual Machine
   |
   | Ansible
   v
Nginx + configuration
   |
   v
Reverse proxy
   |
   v
```

Docker application

