***Задание 1***

- Результат выполнения audit-плейбука:
Я выбрал такие пункты для проведения аудита: 

1. 6.1.2 — права на /etc/passwd (0644, root:root)
2. 6.1.4 — права на /etc/shadow (root:shadow, не шире 0640)
3. 1.5.3 — ASLR включён (kernel.randomize_va_space = 2)
4. 1.5.1 — core dump'ы запрещены (fs.suid_dumpable=0 + hard core 0 в limits.conf)
5. 5.2.x — SSH MaxAuthTries <= 4

`ansible-playbook 01-cis-ig1-audit.yml`

![Снимок экрана 2026-10-06 в 06.48.02 1.png](screenshots/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%202026-10-06%20%D0%B2%2006.48.02%201.png)


***Задание 2***

`ansible-playbook site.yml`

![Снимок экрана 2026-10-06 в 08.02.47.png](screenshots/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%202026-10-06%20%D0%B2%2008.02.47.png)

Проверка отработки плейбука:

- Проверка сконфигурированного порта и доступности сайта:

![Снимок экрана 2026-10-27 в 01.39.52.png](screenshots/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%202026-10-27%20%D0%B2%2001.39.52.png)

Внутри при запросе на http://localhost:8080/ получили ответ 200:ok

Снаружи:

![Снимок экрана 2026-10-27 в 01.41.32.png](screenshots/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%202026-10-27%20%D0%B2%2001.41.32.png)

- Проверка рапоты брендмауэара:

![Снимок экрана 2026-10-27 в 06.07.12.png](screenshots/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%202026-10-27%20%D0%B2%2006.07.12.png)

- Проверка подключения по ssh, проверка наличия auditd:

![Снимок экрана 2026-10-27 в 06.41.54.png](screenshots/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%202026-10-27%20%D0%B2%2006.41.54.png)

permitrootlogin no — вход по SSH под пользователем root запрещён.
passwordauthentication no — вход по SSH с паролем запрещён, разрешён только вход по ключу (publickey)