#!/bin/bash
# Não-destrutivo: só consulta o estado, nunca altera nada.
set -uo pipefail

pass=true

if vgs --noheadings -o vg_name vg_conteudo >/dev/null 2>&1; then
  echo "OK: volume group vg_conteudo existe"
else
  echo "FALHOU: volume group vg_conteudo não existe"
  pass=false
fi

if lvs --noheadings -o lv_name vg_conteudo/lv_midia >/dev/null 2>&1; then
  echo "OK: logical volume lv_midia existe em vg_conteudo"

  lv_size_g="$(lvs --noheadings --units g --nosuffix -o lv_size vg_conteudo/lv_midia 2>/dev/null | tr -d ' ')"
  if awk -v v="${lv_size_g:-0}" 'BEGIN{exit !(v>=3.9)}' 2>/dev/null; then
    echo "OK: lv_midia tem pelo menos ~4GB (${lv_size_g}G)"
  else
    echo "FALHOU: lv_midia tem menos de 4GB (atual: ${lv_size_g:-desconhecido}G)"
    pass=false
  fi

  fstype="$(lsblk -no FSTYPE /dev/vg_conteudo/lv_midia 2>/dev/null)"
  if [ "$fstype" = "xfs" ]; then
    echo "OK: lv_midia está formatado com XFS"
  else
    echo "FALHOU: lv_midia não está formatado com XFS (atual: ${fstype:-nenhum})"
    pass=false
  fi
else
  echo "FALHOU: logical volume lv_midia não existe em vg_conteudo"
  pass=false
fi

if mountpoint -q /midia; then
  echo "OK: /midia está montado"
else
  echo "FALHOU: /midia não está montado"
  pass=false
fi

mounted_src="$(findmnt -no SOURCE /midia 2>/dev/null)"
if echo "$mounted_src" | grep -q 'vg_conteudo-lv_midia'; then
  echo "OK: /midia está montado a partir de vg_conteudo/lv_midia"
else
  echo "FALHOU: /midia não está montado a partir do logical volume esperado (atual: ${mounted_src:-nenhum})"
  pass=false
fi

if findmnt --fstab /midia >/dev/null 2>&1; then
  echo "OK: /midia tem entrada persistente em /etc/fstab"
else
  echo "FALHOU: /midia não tem entrada válida em /etc/fstab"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
