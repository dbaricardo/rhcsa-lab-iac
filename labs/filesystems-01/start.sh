#!/bin/bash
# Idempotente: não cria nada, só localiza o disco de ~1GB (por tamanho,
# nunca por nome fixo) e confirma que o host está pronto.
set -euo pipefail
source /usr/local/lib/lab-common.sh

disco="$(resolve_disco 1)" || {
  echo "filesystems-01: não encontrei um disco de ~1GB livre em $(hostname -s)." >&2
  exit 1
}

echo "Ambiente pronto para 'filesystems-01' em $(hostname -s)."
echo "Disco identificado para este exercício: ${disco} (~1GB)."
echo "Crie as duas partições (ext4 em /appdata, swap ativa) e rode: lab grade filesystems-01"
