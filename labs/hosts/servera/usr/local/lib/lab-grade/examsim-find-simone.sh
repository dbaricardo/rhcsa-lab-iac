#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

[ -d /root/found ]; check $? "/root/found existe"

mapfile -t originais < <(find / \( -path /proc -o -path /sys -o -path /root/found \) -prune -o -user Simone -type f -print 2>/dev/null)
total=${#originais[@]}

if [ "$total" -eq 0 ]; then
    echo "FALHOU: nenhum arquivo de Simone encontrado no sistema (ambiente inconsistente)"
    FAIL=1
else
    faltando=0
    for f in "${originais[@]}"; do
        base=$(basename "$f")
        target="/root/found/$base"
        if [ ! -f "$target" ] || [ -L "$target" ] || ! cmp -s "$f" "$target"; then
            faltando=$((faltando + 1))
        fi
    done
    if [ "$faltando" -eq 0 ]; then
        echo "OK: todos os $total arquivos de Simone estao copiados em /root/found"
    else
        echo "FALHOU: $faltando de $total arquivos de Simone nao encontrados em /root/found"
        FAIL=1
    fi
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
