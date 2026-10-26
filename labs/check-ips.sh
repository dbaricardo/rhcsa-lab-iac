#!/bin/bash
# Prova que nenhum IP / texto exclusivo do homelab sobrou nos labs legados portados
# (labs/hosts/**), nas soluções (tests/solutions/**) e no role lab_common.
# Uso: bash labs/check-ips.sh   (rc 0 = limpo)
set -u
cd "$(dirname "$0")/.." || exit 2
ALVOS=(labs/hosts tests/solutions ansible/roles/lab_common labs/README.md)
# 192.168.10.x em forma literal, escapada para regex (192\.168\.10) ou em classe ([.]).
PADRAO='192(\.|\\\.|\[\.\])168(\.|\\\.|\[\.\])10(\.|\\\.|\[\.\])|noVNC|qm (reboot|start|stop)|VMID|VM 13[0-3]'
if grep -rnE "$PADRAO" "${ALVOS[@]}" | grep -v '^labs/check-ips.sh:' | grep -v 'labs/README.md:.*→'; then
    echo "FALHOU: restos do homelab encontrados (acima)"; exit 1
fi
echo "OK: nenhum 192.168.10.x / noVNC / qm / VMID em ${ALVOS[*]}"
