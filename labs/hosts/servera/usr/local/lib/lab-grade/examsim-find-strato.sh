#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

[ -f /searchfile ]; check $? "/searchfile existe"

if [ -f /searchfile ]; then
    diff <(grep strato /usr/share/dict/words 2>/dev/null | sort) <(sort /searchfile) &>/dev/null
    check $? "/searchfile contem exatamente as ocorrencias de 'strato' em /usr/share/dict/words"
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
