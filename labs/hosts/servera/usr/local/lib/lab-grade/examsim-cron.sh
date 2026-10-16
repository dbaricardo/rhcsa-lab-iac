#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

cn=$(crontab -l -u natasha 2>/dev/null | grep -v '^#' | grep -v '^$')
echo "$cn" | grep -qE '^[[:space:]]*23[[:space:]]+14[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+/bin/echo[[:space:]]+hello[[:space:]]*$'
check $? "cron de natasha: 23 14 * * * /bin/echo hello (atual: '$cn')"

ch=$(crontab -l -u harry 2>/dev/null | grep -v '^#' | grep -v '^$')
echo "$ch" | grep -qE '^[[:space:]]*\*/3[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+/usr/bin/logger'
check $? "cron de harry roda a cada 3 min via /usr/bin/logger"
echo "$ch" | grep -q 'EX200 in progress'
check $? "cron de harry inclui a mensagem 'EX200 in progress' (atual: '$ch')"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
