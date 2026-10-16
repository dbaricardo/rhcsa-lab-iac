# Dominio 4 / lvm: criar PV. Params: DSIZE
ID=dyn-lvm-pv-create
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "disco $D limpo, sem LVM."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    pvs --noheadings -o pv_name 2>/dev/null | grep -qwF "$D"; check $? "$D foi inicializado como volume fisico (PV)"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "limpeza: disco $D zerado."
}
run "$@"
