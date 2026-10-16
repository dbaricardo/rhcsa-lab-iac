# Dominio 4 / filesystems: mkfs numa particao vazia. Params: DSIZE FSTYPE
ID=dyn-fs-create
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    disk_gpt "$D" 501 || exit 1
    P=$(disk_part "$D" 1); wait_dev "$P" || { echo "ERRO: $P nao apareceu"; exit 1; }
    echo "$P (500 MiB) existe e esta sem filesystem."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" 1)
    tipo=$(blkid -s TYPE -o value "$P" 2>/dev/null)
    [ "$tipo" = "$FSTYPE" ]; check $? "$P esta formatada como $FSTYPE (atual: ${tipo:-sem filesystem})"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    echo "limpeza: disco $D zerado."
}
run "$@"
