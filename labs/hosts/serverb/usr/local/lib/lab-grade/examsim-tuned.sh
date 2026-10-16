#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

rec=$(tuned-adm recommend 2>/dev/null | tr -d '[:space:]')
act=$(tuned-adm active 2>/dev/null | sed -n 's/Current active profile: //p' | tr -d '[:space:]')
[ "$rec" = "$act" ]; check $? "profile ativo ($act) bate com o recomendado ($rec)"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
