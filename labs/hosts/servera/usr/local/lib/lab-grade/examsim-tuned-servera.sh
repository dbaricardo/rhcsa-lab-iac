#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

rpm -q tuned &>/dev/null; check $? "pacote tuned instalado"
systemctl is-enabled -q tuned 2>/dev/null; check $? "tuned habilitado no boot"
systemctl is-active -q tuned 2>/dev/null; check $? "tuned ativo"
ATIVO=$(tuned-adm active 2>/dev/null | sed -n 's/^Current active profile: //p')
[ "$ATIVO" = "throughput-performance" ]
check $? "perfil ativo e throughput-performance (atual: ${ATIVO:-nenhum})"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
