#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }
MNT=/mnt/examsim-data

vgs vg_data &>/dev/null; check $? "VG vg_data existe"
PVS=$(vgs --noheadings -o pv_count vg_data 2>/dev/null | tr -d ' ')
[ "${PVS:-0}" -ge 2 ]; check $? "vg_data estendido com um segundo PV (PVs atuais: ${PVS:-0})"

SIZE=$(lvs --noheadings --units m --nosuffix -o lv_size vg_data/lv_data 2>/dev/null | tr -d ' ')
SIZE=${SIZE%.*}
[ -n "$SIZE" ] && [ "$SIZE" -ge 590 ] && [ "$SIZE" -le 610 ]
check $? "lv_data entre 590 e 610 MiB (atual: ${SIZE:-?}M)"

mountpoint -q "$MNT"; check $? "$MNT montado"
SOURCE=$(findmnt -no SOURCE "$MNT" 2>/dev/null)
[ "$SOURCE" = "/dev/mapper/vg_data-lv_data" ]; check $? "$MNT montado a partir de vg_data/lv_data (origem: ${SOURCE:-nenhuma})"
# Secao de dados do xfs_info, nao o df: no RHEL 10 o log/metadados comem ~64M
# e um xfs de 600 MiB aparece no df com ~536M.
FS=$(xfs_info "$MNT" 2>/dev/null | awk '/^data/{for(i=1;i<=NF;i++){if($i~/^bsize=/)b=substr($i,7); if($i~/^blocks=/)n=substr($i,8)}} END{if(b&&n)print int(b*n/1048576)}')
[ "${FS:-0}" -ge 590 ]; check $? "filesystem xfs acompanhou o LV (xfs_info: ${FS:-0}M, esperado >= 590M)"

UUID=$(blkid -s UUID -o value /dev/vg_data/lv_data 2>/dev/null)
awk -v u="UUID=$UUID" -v m="$MNT" '$1!~/^#/ && $2==m && ($1=="/dev/mapper/vg_data-lv_data" || $1=="/dev/vg_data/lv_data" || $1==u){f=1} END{exit !f}' /etc/fstab
check $? "/etc/fstab monta vg_data/lv_data em $MNT"
[ -f "$MNT/teste-examsim24.txt" ]; check $? "arquivo de teste preservado apos a extensao"

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
