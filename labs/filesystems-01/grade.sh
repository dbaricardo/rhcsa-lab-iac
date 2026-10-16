#!/bin/bash
# Não-destrutivo: só consulta o estado, nunca altera nada.
#
# Usa disco_por_tamanho() (não resolve_disco()) de propósito: neste ponto o
# disco já foi particionado pelo estudante (é o próprio exercício), e
# resolve_disco() exige explicitamente um disco CRU (sem partições) -- ela
# serve para start.sh escolher o disco, não para reencontrá-lo depois de
# particionado. Usar resolve_disco() aqui faria este grade.sh reportar
# FALHOU sempre, mesmo com o exercício resolvido corretamente (mesma classe
# de bug já documentada em docs/explanation/problemas-conhecidos.md e corrigida em
# labs/storage-lvm-01/finish.sh).
set -uo pipefail
source /usr/local/lib/lab-common.sh

pass=true

disco="$(disco_por_tamanho 1 2>/dev/null)"
if [ -z "${disco:-}" ]; then
  echo "FALHOU: não foi possível identificar o disco de ~1GB (vmdata2)"
  echo "RESULTADO: FALHOU"
  exit 0
fi
echo "OK: disco de ~1GB identificado (${disco})"

part_count="$(lsblk -nrpo NAME,TYPE "$disco" 2>/dev/null | awk '$2=="part"' | wc -l)"
if [ "$part_count" -ge 2 ]; then
  echo "OK: disco tem pelo menos 2 partições (${part_count})"
else
  echo "FALHOU: disco tem menos de 2 partições (${part_count})"
  pass=false
fi

ext4_part="$(lsblk -nrpo NAME,FSTYPE "$disco" 2>/dev/null | awk '$2=="ext4"{print $1; exit}')"
if [ -n "$ext4_part" ]; then
  echo "OK: encontrada partição ext4 (${ext4_part})"
else
  echo "FALHOU: nenhuma partição ext4 encontrada em ${disco}"
  pass=false
fi

if mountpoint -q /appdata; then
  echo "OK: /appdata está montado"
  mounted_src="$(findmnt -no SOURCE /appdata 2>/dev/null)"
  if [ -n "$ext4_part" ] && [ "$mounted_src" = "$ext4_part" ]; then
    echo "OK: /appdata está montado a partir da partição ext4 esperada"
  else
    echo "FALHOU: /appdata não está montado a partir da partição ext4 identificada (atual: ${mounted_src:-nenhum})"
    pass=false
  fi
else
  echo "FALHOU: /appdata não está montado"
  pass=false
fi

if findmnt --fstab /appdata >/dev/null 2>&1; then
  echo "OK: /appdata tem entrada persistente em /etc/fstab"
else
  echo "FALHOU: /appdata não tem entrada válida em /etc/fstab"
  pass=false
fi

swap_part="$(lsblk -nrpo NAME,FSTYPE "$disco" 2>/dev/null | awk '$2=="swap"{print $1; exit}')"
if [ -n "$swap_part" ]; then
  echo "OK: encontrada partição swap (${swap_part})"

  if swapon --show=NAME 2>/dev/null | tail -n +2 | grep -qx "$swap_part"; then
    echo "OK: partição swap está ativa (swapon --show)"
  else
    echo "FALHOU: partição swap não está ativa (ver swapon --show)"
    pass=false
  fi

  swap_uuid="$(blkid -s UUID -o value "$swap_part" 2>/dev/null || true)"
  swap_ref_found=false
  if grep -Eq "^${swap_part}[[:space:]]" /etc/fstab 2>/dev/null; then
    swap_ref_found=true
  elif [ -n "$swap_uuid" ] && grep -Fq "UUID=${swap_uuid}" /etc/fstab 2>/dev/null; then
    swap_ref_found=true
  fi
  if $swap_ref_found; then
    echo "OK: /etc/fstab tem uma entrada persistente para a partição swap"
  else
    echo "FALHOU: /etc/fstab não referencia a partição swap desta exercício (por path ou UUID)"
    pass=false
  fi
else
  echo "FALHOU: nenhuma partição swap encontrada em ${disco}"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
