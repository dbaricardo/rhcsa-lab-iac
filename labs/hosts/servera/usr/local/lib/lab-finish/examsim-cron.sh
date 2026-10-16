#!/bin/bash
set -u
crontab -r -u natasha 2>/dev/null
crontab -r -u harry 2>/dev/null
# Na prova completa o finish da questao 5 apaga natasha/harry antes deste; sem
# o usuario o crontab -r falha e o spool fica orfao (volta se o usuario for recriado).
rm -f /var/spool/cron/natasha /var/spool/cron/harry
echo "OK: item 7 limpo (crontabs removidas). Usuarios natasha/harry preservados (reaproveitados por outros itens)."
