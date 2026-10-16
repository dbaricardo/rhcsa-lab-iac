#!/bin/bash
# So roda depois que o SSH ja voltou a responder (aluno ja terminou o boot).
# Diferente do lab oficial rootpw-recover: aqui o enunciado (item 1 do
# simulado) fixa a senha esperada como 'atenorth' -- entao da pra checar
# de verdade, sem "adivinhar".
set -u
source /usr/local/lib/lab-common.sh
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

verifica_senha root atenorth
check $? "senha de root e 'atenorth' (recuperada com sucesso)"

ENFORCE=$(getenforce 2>/dev/null)
[ "$ENFORCE" = "Enforcing" ]; check $? "SELinux em Enforcing em runtime (getenforce: $ENFORCE)"

CONFIG_MODE=$(grep -E '^SELINUX=' /etc/selinux/config 2>/dev/null)
[ "$CONFIG_MODE" = "SELINUX=enforcing" ]; check $? "/etc/selinux/config define SELINUX=enforcing"

UNLABELED=$(ls -Z /etc/shadow /etc/passwd /etc/gshadow /etc/group 2>/dev/null | grep -ic 'unlabeled_t')
[ "$UNLABELED" -eq 0 ]; check $? "sem contexto unlabeled_t em /etc/shadow,passwd,gshadow,group"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
