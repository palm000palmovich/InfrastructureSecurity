# Hardening lab playbooks

Ansible-плейбуки для задания по hardening'у ВМ, созданной в `InfrastructureInit` (terraform).

## Что делают плейбуки

### Задание 1 — `01-cis-ig1-audit.yml`

Аудит (без исправления) 5 настроек уровня **IG1** из CIS Debian Linux Benchmark:

| № | Контроль | Что проверяется |
|---|---|---|
| 1 | 6.1.2 | Права на `/etc/passwd` — `0644`, владелец `root:root` |
| 2 | 6.1.4 | Права на `/etc/shadow` — не шире `0640`, владелец `root:shadow` |
| 3 | 1.5.3 | ASLR включён (`kernel.randomize_va_space = 2`) |
| 4 | 1.5.1 | Core dump'ы запрещены (`fs.suid_dumpable=0` + `hard core 0` в `limits.conf`) |
| 5 | 5.2.x | `sshd`: `MaxAuthTries <= 4` |

Плейбук только читает состояние системы (`changed_when: false` на всех проверках) и печатает отчёт PASS/FAIL по каждому пункту плюс итоговую сводку.

### Задание 2 — `site.yml` (импортирует 02–04 по порядку)

1. **`02-webserver.yml`** — ставит `nginx`, создаёт нестандартную домашнюю директорию сайта (`{{ web_root }}`), выкладывает в неё `files/website/index.html`, настраивает vhost из `templates/nginx-site.conf.j2` на нестандартный порт (`{{ web_port }}`) и отключает дефолтный сайт.
2. **`03-firewall.yml`** — ставит `ufw`, политика по умолчанию deny-incoming/allow-outgoing, явно разрешает только `{{ allowed_ports }}` (SSH + порт веб-сервера).
3. **`04-ssh-harden.yml`** — `PasswordAuthentication no`, `PermitRootLogin no`, ставит и включает `auditd`.

## Структура

```
playbook/
├── ansible.cfg              # инвентарь по умолчанию, отключение host key checking
├── site.yml                 # запускает 02-04 по порядку
├── 01-cis-ig1-audit.yml     # задание 1, запускается отдельно
├── 02-webserver.yml
├── 03-firewall.yml
├── 04-ssh-harden.yml
├── inventory/
│   └── prod.yml             # хост hardening-vm (внешний IP из terraform output)
├── group_vars/
│   ├── all.yml               # параметры подключения для всех групп
│   └── hardening.yml         # параметры веб-сервера и firewall'а
├── files/
│   └── website/index.html   # содержимое сайта из задания 2.1
└── templates/
    └── nginx-site.conf.j2   # шаблон vhost-конфига nginx
```

## Параметры (переменные)

### `group_vars/all.yml` — общие для всех хостов

| Переменная | Значение по умолчанию | Описание |
|---|---|---|
| `ansible_user` | `ubuntu` | пользователь для SSH-подключения (дефолтный юзер образа `ubuntu-2204-lts`) |
| `ansible_become` | `true` | все задачи выполняются через `sudo` |
| `ansible_ssh_private_key_file` | `~/.ssh/id_ed25519` | приватный ключ для подключения |
| `ansible_python_interpreter` | `/usr/bin/python3` | путь к интерпретатору Python на хосте |

### `group_vars/hardening.yml` — специфичные для группы `hardening`

| Переменная | Значение по умолчанию | Описание |
|---|---|---|
| `web_port` | `8080` | нестандартный порт, на котором слушает nginx |
| `web_root` | `/srv/mysite` | нестандартная домашняя директория сайта |
| `ssh_port` | `22` | порт SSH, который остаётся открытым в ufw |
| `allowed_ports` | `[ssh_port, web_port]` | список портов, разрешённых в ufw |

Переопределить любой параметр можно через `-e`, например:

```bash
ansible-playbook site.yml -e web_port=9090
```

## Теги

| Тег | Где используется | Что выполняет |
|---|---|---|
| `audit` | `01-cis-ig1-audit.yml` | все 5 проверок CIS IG1 |
| `packages` | `02-webserver.yml`, `03-firewall.yml` | установка `nginx`/`ufw` |
| `deploy` | `02-webserver.yml` | директория и файлы сайта |
| `nginx` | `02-webserver.yml` | конфиг vhost, enable/disable сайтов, запуск сервиса |
| `firewall` | `03-firewall.yml` | политики и правила `ufw` |
| `ssh` | `04-ssh-harden.yml` | настройки `sshd_config` |
| `auditd` | `04-ssh-harden.yml` | установка и запуск `auditd` |

Примеры запуска с тегами:

```bash
# только пересобрать конфиг nginx, не трогая установку пакетов
ansible-playbook site.yml --tags nginx

# пропустить auditd (например, он уже настроен)
ansible-playbook 04-ssh-harden.yml --skip-tags auditd
```

## Запуск

```bash
# аудит задания 1 (ничего не меняет на хосте)
ansible-playbook 01-cis-ig1-audit.yml

# проверка синтаксиса
ansible-playbook site.yml --syntax-check

# dry-run с выводом диффа
ansible-playbook site.yml --check --diff

# полный прогон задания 2
ansible-playbook site.yml
```

Инвентарь по умолчанию берётся из `inventory/prod.yml` (настроено в `ansible.cfg`), группа `hardening` содержит хост `hardening-vm` — ВМ из `InfrastructureInit`.
