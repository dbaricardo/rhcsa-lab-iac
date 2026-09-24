#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh. Descobre o PV pelo VG (em
# vez de confiar em resolve_disco de novo) porque, depois que o estudante
# particionou/formatou o disco, seu "tamanho cru" pode não bater mais
# exatamente com o esperado por resolve_disco.
set -uo pipefail

umount -f /midia >/dev/null 2>&1 || true
sed -i '/[[:space:]]\/midia[[:space:]]/d' /etc/fstab 2>/dev/null || true

pv_path="$(pvs --noheadings -o pv_name --select vg_name=vg_conteudo 2>/dev/null | awk '{print $1}')"

lvremove -f /dev/vg_conteudo/lv_midia >/dev/null 2>&1 || true
vgremove -f vg_conteudo >/dev/null 2>&1 || true
if [ -n "$pv_path" ]; then
  pvremove -f "$pv_path" >/dev/null 2>&1 || true
  wipefs -a "$pv_path" >/dev/null 2>&1 || true
fi

rmdir /midia >/dev/null 2>&1 || true

echo "Ambiente de 'storage-lvm-01' limpo em $(hostname -s)."
exit 0
