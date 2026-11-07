1) ***Seccomp*** — фильтр на уровне системных вызовов (syscalls).

Это механизм ядра Linux, который ограничивает набор системных вызовов, доступных процессу. Простыми словами: программа живёт в «клетке», где можно дёргать только разрешённые syscall.

**Зачем**

Уменьшить поверхность атаки: чем меньше syscalls — тем меньше уязвимостей ядра можно эксплуатировать.

Не дать программе делать то, что ей не положено (например, execve, чтобы не «выпрыгнуть» в shell).

Два режима

- Strict mode — разрешены только read, write (по уже открытым fd), exit, sigreturn. Практически не используется.

- Filter mode — основной. Правила через cBPF (classic BPF). Для каждого правила задаётся действие:

    SCMP_ACT_KILL — убить процесс (SIGSYS);

    SCMP_ACT_ERRNO(x) — вернуть ошибку;

    SCMP_ACT_LOG — только лог;

    SCMP_ACT_ALLOW — разрешить.


2) **SELinux** — MAC-политики на уровне типов объектов и доменов процессов (сложный, корпоративный).

Это система MAC (Mandatory Access Control) в ядре. Каждому объекту и процессу назначается контекст безопасности, и политика разрешает/запрещает взаимодействия.

**Контекст безопасности**

`user:role:type:level`

- user — SELinux-пользователь (unconfined_u, staff_u…), не путать с обычным.

- role — роль (object_r для файлов, system_r/unconfined_r для процессов).

- type / domain — главный компонент. У файла — type (httpd_sys_content_t), у процесса — domain (httpd_t).

- level — уровень (MLS, например «секретно»).


**Режимы**

- Enforcing — политики применяются, запреты работают.

- Permissive — только логирует (AVC), не блокирует (для отладки).


**Политики**

- TE (Type Enforcement) — основная: allow домен тип:класс { действия }. Пример: allow httpd_t httpd_sys_content_t:file { getattr open read }.

- RBAC — роли определяют, какие домены доступны пользователю.

- MLS — многоуровневая безопасность (секретность).


3) **AppArmor** — MAC-политики на уровне путей к файлам (проще, «из коробки» в Ubuntu).

Это MAC-система в ядре, но проще SELinux: политики привязаны к путям к файлам, а не к типам. В Ubuntu включена по умолчанию.



***Выполнение лабораторной работы.***

**Задание 1. Ограничить syscalls через Firejail для трёх утилит**

0) **Проверка наличия утилиты Firejail**

`firejail --version
firejail version 0.9.72`

1) **Утилита cat**

- Узнаем набор syscalls через strace:


![alt text](<screenshots/Screenshot From 2026-11-07 10-08-16.png>)


# Задание 1.1 — Таблица syscalls для `cat`

Источник: `strace -c -f cat /etc/hostname >/dev/null` на Ubuntu 26.04 / ARM aarch64.

Всего: **138 вызовов**, 7 из них с ошибкой (`errors`).

---

## Таблица: syscall → зачем нужен

| Syscall | Calls | Errors | Категория | Зачем нужен `cat` | Что будет, если запретить |
|---|---:|---:|---|---|---|
| `execve` | 1 | 0 | запуск | заменить образ процесса на `/usr/bin/cat` | `cat` **не запустится** |
| `mmap` | 22 | 0 | память | загрузка `.so` (libselinux, libc), heap, стек потока, анонимная память | `cat` падает на старте (не загрузит библиотеки) |
| `mprotect` | 13 | 0 | память | смена прав на страницы (RELRO, guard pages, `PROT_NONE` → `RW`) | падение при инициализации линкера |
| `munmap` | 12 | 0 | память | освобождение временных маппингов | утечка/падение при `exit` |
| `brk` | 3 | 0 | память | рост heap (malloc) | падение glibc при первом `malloc` |
| `openat` | 11 | 1 | файлы | открыть `ld.so.cache`, `libselinux.so.1`, `libc.so.6`, `/etc/hostname` | **`cat` не откроет файл** → `Bad system call` |
| `read` | 13 | 0 | файлы | прочитать содержимое `.so` и `/etc/hostname` | не прочитает файл |
| `close` | 12 | 0 | файлы | закрыть fd | утечка fd, но обычно не падает |
| `fstat` | 10 | 0 | файлы | размер/тип fd (для `mmap`, `read`) | не сможет корректно прочитать файл |
| `statx` | 5 | 0 | файлы | современный `stat` (размер/тип/таймстемпы) | проблемы с метаданными файла |
| `faccessat` | 2 | 2 | файлы | проверка `/etc/ld.so.preload` (всегда `ENOENT` — норма) | ошибка загрузки линкера |
| `statfs` | 2 | 2 | файлы | проверить ФС (обычно для `/proc`/`/sys` при инициализации glibc) | падение glibc |
| `splice` | 4 | 1 | файлы/IO | zero-copy передача между fd (glibc/`sendfile`-путь) | не критично, но glibc может упасть |
| `pipe2` | 1 | 0 | IPC | создать pipe (внутренние механизмы glibc/NSS) | падение при инициализации NSS |
| `fcntl` | 4 | 0 | файлы | манипуляции с fd (флаги, блокировки) | проблемы с fd |
| `ioctl` | 1 | 1 | терминал | размер терминала / проверка типа tty | обычно не критично |
| `rt_sigaction` | 9 | 0 | сигналы | установить обработчики (SIGPIPE, SIGSEGV, etc.) | glibc падает на старте |
| `sigaltstack` | 3 | 0 | сигналы | альтернативный стек для сигналов | падение при инициализации |
| `sched_getaffinity` | 1 | 0 | CPU | узнать маску CPU (для glibc) | не критично |
| `prlimit64` | 2 | 0 | процесс | лимиты (`ulimit -n`, `ulimit -c`) | не критично |
| `prctl` | 1 | 0 | процесс | настройки процесса (ASLR, dumpable) | не критично |
| `ppoll` | 1 | 0 | IO | ожидание событий | не критично |
| `set_tid_address` | 1 | 0 | потоки | TLS/потоки glibc | glibc падает на старте |
| `set_robust_list` | 1 | 0 | потоки | futex-очистка | glibc падает на старте |
| `gettid` | 1 | 0 | потоки | ID потока | не критично |
| `getrandom` | 1 | 0 | рандом | ASLR, stack canary | падение при инициализации |
| `rseq` | 1 | 0 | потоки | restartable sequences (glibc ≥ 2.35) | падение при инициализации |

---

## Пояснение по категориям

### Запуск (1 syscall)
- **`execve`** — единственный вызов, который **обязателен для запуска**. Firejail ставит фильтр **после** `execve`, поэтому `drop=execve` не мешает `cat` стартовать, но **запрещает** ему породить shell. Для самого `cat` в `keep` `execve` нужен, только если фильтр ставится до запуска (по умолчанию Firejail — нет).

### Память (50 syscalls — 22+13+12+3)
- **`mmap`/`mprotect`/`munmap`** — загрузка динамических библиотек линкером (`ld-linux-aarch64.so.1`), а также heap/stack/TLS.
- **`brk`** — расширение кучи для `malloc`.
- Это самая «тяжёлая» категория по числу вызовов, но **без неё `cat` не стартует**.

### Файлы (36 syscalls)
- **`openat`/`read`/`close`/`fstat`** — работа с файлами: и линкер (`.so`), и сам `cat` (`/etc/hostname`).
- **`statx`** — современная замена `fstat`/`newfstatat`.
- **`faccessat`** — проверка `/etc/ld.so.preload` (2 ошибки `ENOENT` — норма).
- **`statfs`** — проверка файловой системы (2 ошибки — норма).
- **`splice`** — zero-copy; 1 ошибка — не критично.
- **`fcntl`** — флаги fd.

### Сигналы и потоки (15 syscalls)
- **`rt_sigaction`/`sigaltstack`** — обработчики сигналов (glibc).
- **`set_tid_address`/`set_robust_list`/`gettid`/`rseq`** — TLS и futex (glibc).
- Без них glibc **падает на старте**.

### Служебное (5 syscalls)
- **`getrandom`** — энтропия для ASLR и stack canary.
- **`prlimit64`/`prctl`/`sched_getaffinity`/`ppoll`** — лимиты, настройки, CPU-маска.

---

## Что важно для пункта 1.2 (поломка)

| Что запрещаем | Что происходит | Почему |
|---|---|---|
| `openat` | `Bad system call (core dumped)` | `cat` не может открыть `/etc/hostname` (или загрузить `libselinux.so.1` — упадёт ещё на старте) |
| `read` | `cat` не выводит данные | не может прочитать содержимое файла |
| `execve` | `cat` **не запускается** | нет замены образа процесса |
| `mmap` | падение на старте | линкер не может загрузить `.so` |
| `rt_sigaction` | падение на старте | glibc не инициализирует обработчики |

---

## Белый список для `firejail --seccomp.keep`

Все 26 имён из таблицы (без `total`):

```bash
firejail --seccomp.keep=execve,mmap,mprotect,munmap,brk,openat,read,close,fstat,statx,faccessat,statfs,splice,pipe2,fcntl,ioctl,rt_sigaction,sigaltstack,sched_getaffinity,prlimit64,prctl,ppoll,set_tid_address,set_robust_list,gettid,getrandom,rseq \
  cat /etc/hostname
  ```


## 1.2 Частичное удаление сисколлов 

а) утилита cat

- Попробуем запустить утилиту через firejail:

![alt text](<screenshots/Screenshot From 2026-11-07 10-34-57.png>)

- Разрешим только сисколл write в белом списке:

![alt text](<screenshots/Screenshot From 2026-11-07 12-06-22.png>)

Видим код 133(128 + 5), где 5 - это сигнал SIGTRAP, который молча убивает процесс.

б) утилита ls

`firejail --noprofile --seccomp.keep=write bash -c 'ls /tmp'`

Тут также получили код 133, ее вызов не смог прочитать содержимое дериктории.

в) утилита find

firejail --noprofile --seccomp.keep=write bash -c 'find /tmp -maxdepth 1'
echo "EXIT=$?"

Аналогичный исход.

**Вывод**

firejail в себя принимает все необходимые сисколлы для запуска утилит, если каких-то не хватает, срабатывает фильтр и завершает процесс.


# 2. Ограничение доступа веб-сервиса через AppArmor.

- Проверка состояния AppArmor:

![alt text](<screenshots/Screenshot From 2026-11-07 12-33-52.png>)

Нас интересует строка `apparmor module is loaded`. is loaded => все ок.

- Запуск nginx и проверка его работоспособности:

`sudo systemctl enable --now nginx`

![alt text](<screenshots/Screenshot From 2026-11-07 12-43-18.png>)

- Создание файла со статикой:

![alt text](<screenshots/Screenshot From 2026-11-07 12-46-32.png>)

- Создание конфига для nginx:

![alt text](<screenshots/Screenshot From 2026-11-07 12-53-23.png>)

![alt text](<screenshots/Screenshot From 2026-11-07 12-59-36.png>)

Настройка прошла успешно.

- Настройка профиля AppArmor.

![alt text](<screenshots/Screenshot From 2026-11-07 13-07-10.png>)

**Обовнование настроек:**

| Блок | Строки профиля | Права | Зачем нужно | Что будет, если убрать |
|---|---|---|---|---|
| **0. Заголовок** | `#include <tunables/global>`<br>`profile nginx-mysite /usr/sbin/nginx flags=(attach_disconnected,mediate_deleted) {` | — | `tunables/global` — глобальные переменные AppArmor (`@{HOME}`, `@{PROC}`); имя профиля `nginx-mysite` — уникальное; `/usr/sbin/nginx` — привязка к бинарнику; `attach_disconnected` — работать после потери namespace; `mediate_deleted` — фильтровать обращения к удалённым файлам | Без `tunables/global` не работают `abstractions/*`; без `attach_disconnected` профиль «теряется» после `unshare`; без `mediate_deleted` удалённый файл доступен через открытый fd |
| **1. Абстракции** | `#include <abstractions/base>`<br>`#include <abstractions/nameservice>` | — | `base` — базовый набор (`/etc/ld.so.cache`, `/dev/urandom`, `/proc/**`, сигналы, сеть); `nameservice` — NSS/DNS (`nsswitch.conf`, `resolv.conf`, `hosts`, `passwd`, `group`) | Любая динамически слинкованная программа не стартует; DNS не работает |
| **2. Запуск бинарника** | `/usr/sbin/nginx mr,` | `r` — read; `m` — mmap | Ядро читает ELF и проецирует в память — без этого nginx не запустится | `Permission denied` при старте; `apparmor="DENIED" operation="exec" name="/usr/sbin/nginx"` |
| **3. Конфиги nginx** | `/etc/nginx/** r,` | `r` — только чтение | nginx читает `nginx.conf`, `sites-enabled/*`, `mime.types`, `conf.d/*.conf` при старте и reload. `**` — рекурсивный glob | nginx не стартует: `open("/etc/nginx/nginx.conf") failed (13: Permission denied)` |
| **4. TLS** | `/etc/ssl/certs/** r,`<br>`/etc/ssl/openssl.cnf r,` | `r` — только чтение | При HTTPS nginx читает сертификаты и openssl-конфиг. Сертификаты — секреты, запись = компрометация | HTTPS не работает: `SSL_CTX_use_certificate_chain_file() failed` |
| **5. MIME** | `/etc/mime.types r,` | `r` — чтение | nginx определяет `Content-Type` по расширению (`.html` → `text/html`, `.css` → `text/css`) | Файлы отдаются как `application/octet-stream` → браузер скачивает вместо открытия |
| **6. NSS** | `/etc/nsswitch.conf r,`<br>`/etc/resolv.conf r,`<br>`/etc/hosts r,`<br>`/etc/passwd r,`<br>`/etc/group r,` | `r` — чтение | Порядок источников имён; DNS-серверы; локальные записи; `getpwnam("www-data")`/`getgrnam` для `setuid` | Без `nsswitch.conf`/`resolv.conf` — DNS не работает; без `passwd`/`group` — `setuid(www-data)` падает, nginx не стартует |
| **7. Линкер и библиотеки** | `/etc/ld.so.cache r,`<br>`/usr/lib/aarch64-linux-gnu/** mr,`<br>`/lib/aarch64-linux-gnu/** mr,` | `r` — read; `m` — mmap | Кеш путей к `.so`; сами библиотеки (на ARM — `aarch64-linux-gnu`). Нужен `m`, потому что код проецируется с `PROT_EXEC` | `error while loading shared libraries: libc.so.6: cannot open shared object file`. На x86_64 пути были бы `x86_64-linux-gnu` — копирование x86-профиля на ARM ломает запуск |
| **8. Контент сайта** | `/var/www/mysite/** r,` | `r` — только чтение | nginx отдаёт статику из вебрута. **Ключевое правило безопасности**: если разрешить `w`, при RCE атакующий зальёт `.php`/`.sh` в вебрут | `curl http://127.0.0.1:8080/` → `403 Forbidden`; `apparmor="DENIED" name="/var/www/mysite/index.html" requested_mask="r"` |
| **9. Логи** | `/var/log/nginx/*.log w,`<br>`/var/log/nginx/*.log.1 w,` | `w` — создание + запись + дозапись (включает `a`) | access/error-логи; при ротации `logrotate` переименовывает `*.log` → `*.log.1`. `w`, а не `a`, потому что нужно создавать новый файл при ротации | Логи не пишутся; возможны 500 на запросах |
| **10. PID-файл** | `/run/nginx.pid rw,`<br>`/run/nginx.pid.* rw,` | `r` — read; `w` — write | nginx пишет PID; systemd читает для `status`/`reload`/`stop`; при reload читает старый и пишет новый | `systemctl reload nginx` падает; возможны проблемы со стартом |
| **11. Временные файлы** | `/var/lib/nginx/** rw,` | `r` — read; `w` — write | Буферы `proxy_temp`, `client_body_temp`, `fastcgi_temp` при `proxy_pass`/upload | `POST` с телом > `client_body_buffer_size` → `500 Internal Server Error` |
| **12. Сеть** | `network inet stream,`<br>`network inet6 stream,` | сеть | nginx слушает TCP на 8080 (`listen 8080;`) — это `inet stream`. IPv6 — `inet6 stream`. UDP (`dgram`) не нужен | `socket() failed (13: Permission denied)` — не bind'ится |
| **13. Netlink** | `network netlink raw,` | сеть | systemd и nginx иногда общаются через netlink (`systemd-notify`, мониторинг) | Обычно ничего критичного; иногда systemd перезапускает по таймауту |
| **14.1. Анти-вебшелл** | `deny /var/www/mysite/** w,`<br>`deny /var/www/mysite/** x,` | запрет `w`, `x` | RCE → нельзя залить `.php`/`.sh` в вебрут; даже если файл там окажется — nginx его не исполнит | RCE → загрузка shell → полная компрометация |
| **14.2. Секреты** | `deny /etc/shadow r,`<br>`deny /etc/shadow- r,`<br>`deny /etc/gshadow r,`<br>`deny /etc/gshadow- r,` | запрет `r` | `/etc/shadow*` — хеши паролей; `/etc/gshadow*` — хеши групп. При RCE — первая цель атакующего | RCE → `cat /etc/shadow` → брутфорс → root |
| **14.3. Домашние каталоги** | `deny /root/** rwklx,`<br>`deny /home/** rwklx,` | запрет `r`, `w`, `k` (lock), `l` (link), `x` (exec) | В `~/.ssh/id_rsa`, `~/.bash_history` — ключи и история. При RCE — lateral movement | RCE → чтение ключей → движение вглубь сети |
| **14.4. Анти-reverse-shell** | `deny /bin/** x,`<br>`deny /usr/bin/** x,` | запрет `x` (exec) | При RCE атакующий делает `execve("/bin/sh")` → reverse shell. `deny x` блокирует это. nginx сам `execve` не вызывает, поэтому правило его не ломает | RCE → `execve("/bin/sh")` → полный контроль |
| **14.5. Запрет `/tmp`** | `deny /tmp/** w,` | запрет `w` | `/tmp` — world-writable; туда кладут эксплойты (`.so` для `LD_PRELOAD`, скрипты для cron, временные файлы reverse-shell). Если nginx использует `/tmp` для `client_body_temp_path` — это сломает POST, поэтому буферы вынесены в `/var/lib/nginx/` | RCE → запись в `/tmp` → второй этап атаки |
| **Итог: capability** | (нет `capability net_bind_service,`) | — | Сайт слушает **8080** (> 1024), привилегированный порт не используется — capability не нужна. При порте **80** пришлось бы добавить `capability net_bind_service,` | Если слушать 80 без capability — `bind() failed (13: Permission denied)` |
| **Итог: проверка** | `sudo apparmor_parser -r ...`<br>`sudo aa-complain ...` → `journalctl -k \| grep DENIED`<br>`sudo aa-enforce ...`<br>`sudo aa-status \| grep nginx-mysite` | — | Сначала `complain` (только логи), чтобы увидеть нехватку правил; затем `enforce` (блокировка). Формат лога: `apparmor="DENIED" operation="open" profile="nginx-mysite" name="..." comm="..." requested_mask="..." denied_mask="..."` | Если сразу `enforce` без `complain` — nginx может упасть на первом же `DENIED`, и причину придётся искать в `journalctl` |

- Проверка корректности профиля:

`sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.nginx.mysite`

Нет выводов => профиль настроен корректно.

- Проверим, что профиль виден:

![alt text](<screenshots/Screenshot From 2026-11-07 13-41-12.png>)

- Переведем профили AppArmor в режим enforce:

`sudo aa-enforce /etc/apparmor.d/usr.sbin.nginx.mysite`


- Проверим, что профиль в enforce и nginx под ним:

![alt text](<screenshots/Screenshot From 2026-11-07 14-10-35.png>)

- Проверим, что запреты работают(чтение секретов):

![alt text](<screenshots/Screenshot From 2026-11-07 14-16-05.png>)