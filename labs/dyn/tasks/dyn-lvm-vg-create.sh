# Dominio 4 / lvm: criar VG. Params: DSIZE VG
ID=dyn-lvm-vg-create
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "disco $D limpo, sem LVM."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    vgs --noheadings "$VG" &>/dev/null; check $? "o grupo de volumes $VG existe"
    pvs --noheadings -o pv_name -S "vg_name=$VG" 2>/dev/null | grep -qwF "$D"; check $? "o VG $VG usa o disco $D"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "limpeza: disco $D zerado."
}
run "$@"
