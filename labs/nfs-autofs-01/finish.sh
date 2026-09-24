#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh. O dispatcher da
# workstation já roda 'finish' na ordem inversa de 'hosts' (serverb antes de
# servera) especificamente para este cenário: cliente desmonta antes do
# servidor remover o export.
set -uo pipefail
host="$(hostname -s)"

case "$host" in
  servera)
    rm -f /etc/exports.d/nfs-autofs-01.exports
    exportfs -ra >/dev/null 2>&1 || true
    rm -rf /export/dados-equipe
    ;;
  serverb)
    umount /mnt/dados-equipe >/dev/null 2>&1 || true
    rm -f /etc/auto.master.d/dados-equipe.autofs
    rm -f /etc/auto.dados-equipe
    systemctl try-restart autofs >/dev/null 2>&1 || true
    rmdir /mnt/dados-equipe >/dev/null 2>&1 || true
    ;;
esac

echo "Ambiente de 'nfs-autofs-01' limpo em $host."
exit 0
