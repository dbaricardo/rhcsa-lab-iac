#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

grep -Eq '^(server|pool)[[:space:]]+classroom\.example\.com' /etc/chrony.conf
check $? "chrony.conf referencia classroom.example.com como fonte"

systemctl is-active chronyd &>/dev/null
check $? "chronyd ativo"

out=$(chronyc -n sources 2>/dev/null)
source_ok=1
while read -r ip; do
    [ -n "$ip" ] && echo "$out" | grep -qw "$ip" && source_ok=0
done < <(getent ahostsv4 classroom.example.com 2>/dev/null | awk '{print $1}' | sort -u)
check "$source_ok" "chronyc sources mostra um IP resolvido de classroom.example.com (saida: '$out')"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
