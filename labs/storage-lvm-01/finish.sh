#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh. Remove o VG/LV pelo nome
# primeiro (mais direto enquanto o LVM ainda existe) e, além disso, limpa o
# disco inteiro por tamanho via disco_por_tamanho() de lab-common.sh -- se
# só a partição/PV fosse limpa, a tabela de partições continuaria no disco
# e resolve_disco() (que exige disco CRU) nunca mais o encontraria no
# próximo "lab start storage-lvm-01", quebrando o exercício permanentemente
# (bug já visto em produção, ver docs/troubleshooting.md).
set -uo pipefail
source /usr/local/lib/lab-common.sh 2>/dev/null || true

umount -f /midia >/dev/null 2>&1 || true
sed -i '/[[:space:]]\/midia[[:space:]]/d' /etc/fstab 2>/dev/null || true

pv_path="$(pvs --noheadings -o pv_name --select vg_name=vg_conteudo 2>/dev/null | awk '{print $1}')"

lvremove -f /dev/vg_conteudo/lv_midia >/dev/null 2>&1 || true
vgremove -f vg_conteudo >/dev/null 2>&1 || true
if [ -n "$pv_path" ]; then
  pvremove -f "$pv_path" >/dev/null 2>&1 || true
  wipefs -a "$pv_path" >/dev/null 2>&1 || true
fi

disco="$(disco_por_tamanho 6 2>/dev/null || true)"
if [ -n "${disco:-}" ]; then
  for part in $(lsblk -nrpo NAME "$disco" 2>/dev/null | tail -n +2); do
    wipefs -a "$part" >/dev/null 2>&1 || true
  done
  wipefs -a "$disco" >/dev/null 2>&1 || true
fi

rmdir /midia >/dev/null 2>&1 || true

echo "Ambiente de 'storage-lvm-01' limpo em $(hostname -s)."
exit 0
