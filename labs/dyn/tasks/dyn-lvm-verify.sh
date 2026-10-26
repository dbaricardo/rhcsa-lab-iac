# Dominio 4 / lvm: criar VG+LV a partir do disco. Params: DSIZE VG LV SIZE
ID=dyn-lvm-verify
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "disco $D limpo, sem LVM."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    lvs --noheadings "$VG/$LV" &>/dev/null; check $? "o volume logico $VG/$LV existe"
    mb=$(lvs --noheadings --nosuffix --units m -o lv_size "$VG/$LV" 2>/dev/null | awk '{printf "%d", $1}')
    [ "${mb:-0}" -ge $((SIZE * 95 / 100)) ] && [ "${mb:-0}" -le $((SIZE * 105 / 100)) ]
    check $? "$LV tem ~$SIZE MB (atual: ${mb:-0} MB)"
    pvs --noheadings -o pv_name -S "vg_name=$VG" 2>/dev/null | grep -qwF "$D"
    check $? "o VG $VG usa o disco $D"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "limpeza: disco $D zerado."
}
run "$@"
