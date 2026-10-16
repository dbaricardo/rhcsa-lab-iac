# Dominio 4 / filesystems: VFAT + mount. Params: DSIZE MOUNT
ID=dyn-fs-vfat
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    disk_gpt "$D" 501 || exit 1
    P=$(disk_part "$D" 1); wait_dev "$P" || { echo "ERRO: $P nao apareceu"; exit 1; }
    rmdir "$MOUNT" 2>/dev/null
    echo "$P (500 MiB) existe e esta sem filesystem."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" 1)
    tipo=$(blkid -s TYPE -o value "$P" 2>/dev/null)
    [ "$tipo" = vfat ]; check $? "$P esta formatada como vfat (atual: ${tipo:-sem filesystem})"
    fonte=$(findmnt -nro SOURCE "$MOUNT" 2>/dev/null | head -1)
    [ "$fonte" = "$P" ]; check $? "$P esta montada em $MOUNT (atual: ${fonte:-nada})"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"
