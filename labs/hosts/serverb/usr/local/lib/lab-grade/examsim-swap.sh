#!/bin/bash
set -u
source /usr/local/lib/lab-common.sh
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

DISCO=$(resolve_disco 1) || DISCO=""
PART="${DISCO}1"

swapon -s | awk -v p="$PART" '$1==p{found=1} END{exit !found}'
check $? "particao $PART ativa como swap (swapon -s)"

FSTAB_OK=1
if [ -b "$PART" ]; then
    UUID=$(blkid -s UUID -o value "$PART" 2>/dev/null)
    if [ -n "$UUID" ] && grep -Eq "UUID=$UUID[[:space:]].*swap" /etc/fstab; then
        FSTAB_OK=0
    elif grep -Eq "^${PART}[[:space:]].*swap" /etc/fstab; then
        FSTAB_OK=0
    fi
fi
check $FSTAB_OK "entrada de swap persistente no /etc/fstab referenciando $PART (por UUID ou caminho)"

SIZE_KB=$(swapon -s | awk -v p="$PART" '$1==p{print $3}')
if [ -n "$SIZE_KB" ]; then
    [ "$SIZE_KB" -ge 250000 ] && [ "$SIZE_KB" -le 265000 ]
    check $? "tamanho da swap de aproximadamente 250 MiB (atual: ${SIZE_KB}KB)"
else
    echo "FALHOU: nao foi possivel ler o tamanho da swap ativa"
    FAIL=1
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
