# Dominio 4 / filesystems: mount persistente por UUID. Params: DSIZE FSTYPE MOUNT OPTIONS
ID=dyn-fs-persistent
do_start() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    disk_gpt "$D" 501 || exit 1
    P=$(disk_part "$D" 1); wait_dev "$P" || { echo "ERRO: $P nao apareceu"; exit 1; }
    case "$FSTYPE" in xfs) mkfs.xfs -q -f "$P" ;; *) mkfs.ext4 -q -F "$P" ;; esac || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "$P esta formatada em $FSTYPE e desmontada."
}
do_grade() {
    D=$(need_disk "$DSIZE") || { check 1 "disco de pratica encontrado"; return; }
    P=$(disk_part "$D" 1)
    fonte=$(findmnt -nro SOURCE "$MOUNT" 2>/dev/null | head -1)
    [ "$fonte" = "$P" ]; check $? "$P esta montada agora em $MOUNT (atual: ${fonte:-nada})"
    u=$(dev_uuid "$P"); linha=$(fstab_line "$MOUNT")
    [ -n "$u" ] && case "$linha" in "UUID=$u "*) true ;; *) false ;; esac
    check $? "o /etc/fstab tem a entrada de $MOUNT identificada por UUID"
    opts=$(echo "$linha" | awk '{print $4}')
    ok=0; for o in $(echo "$OPTIONS" | tr ',' ' '); do case ",$opts," in *",$o,"*) ;; *) ok=1 ;; esac; done
    [ -n "$linha" ] && [ "$ok" -eq 0 ]; check $? "as opcoes do fstab incluem $OPTIONS (atual: ${opts:-nenhuma})"
    tipo=$(blkid -s TYPE -o value "$P" 2>/dev/null)
    [ "$tipo" = "$FSTYPE" ]; check $? "o filesystem continua $FSTYPE (atual: ${tipo:-nenhum})"
    [ -d "$MOUNT" ]; check $? "o ponto de montagem $MOUNT existe"
}
do_finish() {
    D=$(need_disk "$DSIZE") || exit 1
    disk_clean "$D" || exit 1
    rmdir "$MOUNT" 2>/dev/null
    echo "limpeza: disco $D zerado."
}
run "$@"
