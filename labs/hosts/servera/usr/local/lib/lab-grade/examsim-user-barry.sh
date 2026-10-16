#!/bin/bash
set -u
source /usr/local/lib/lab-common.sh
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

id barry &>/dev/null; check $? "usuario barry existe"

if id barry &>/dev/null; then
    uid=$(id -u barry)
    [ "$uid" = "2112" ]; check $? "UID de barry e 2112 (atual: $uid)"

    verifica_senha barry atenorth
    check $? "senha de barry e 'atenorth'"
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
