#!/bin/bash
# Multi-host: este mesmo script é copiado para servera E serverb (ver
# ansible/roles/lab_common) -- ramifica por hostname para preparar o lado
# certo em cada host. Idempotente nos dois ramos.
set -euo pipefail
host="$(hostname -s)"

case "$host" in
  servera)
    mkdir -p /export/dados-equipe
    chmod 0755 /export/dados-equipe
    echo "conteúdo de exemplo" > /export/dados-equipe/leia-me.txt
    echo "Ambiente pronto em servera: crie o export NFS de /export/dados-equipe."
    ;;
  serverb)
    echo "Ambiente pronto em serverb: configure autofs para montar"
    echo "servera:/export/dados-equipe em /mnt/dados-equipe sob demanda."
    ;;
  *)
    echo "nfs-autofs-01: host desconhecido '$host'" >&2
    exit 2
    ;;
esac
