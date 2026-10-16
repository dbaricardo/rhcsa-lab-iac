#!/bin/bash
# Item 7: cron de natasha (diario 14:23, /bin/echo hello) e harry
# (a cada 3 min, /usr/bin/logger "EX200 in progress").
set -u
for u in natasha harry; do
    id "$u" &>/dev/null || useradd -m "$u"
    crontab -r -u "$u" 2>/dev/null
done
echo "OK: usuarios natasha/harry garantidos, crontabs limpas para o item 7."
