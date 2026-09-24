#!/bin/bash
# Idempotente: não cria nada, só localiza o disco de ~6GB (por tamanho,
# nunca por nome fixo) e confirma que o host está pronto.
set -euo pipefail
source /usr/local/lib/lab-common.sh

disco="$(resolve_disco 6)" || {
  echo "storage-lvm-01: não encontrei um disco de ~6GB livre em $(hostname -s)." >&2
  exit 1
}

echo "Ambiente pronto para 'storage-lvm-01' em $(hostname -s)."
echo "Disco identificado para este exercício: ${disco} (~6GB)."
echo "Crie PV/VG (vg_conteudo)/LV (lv_midia, XFS, montado em /midia) e rode: lab grade storage-lvm-01"
