# Dominio 4 / network_storage: mount NFS persistente com _netdev. Params: MOUNT
ID=dyn-nfs-fstab
EXPORT=/exports/dyn-nfsshared
do_server_start() { nfs_export_add nfsfstab "$EXPORT"; echo "export $EXPORT pronto na workstation."; }
do_server_finish() { nfs_export_del nfsfstab "$EXPORT"; echo "limpeza: export $EXPORT removido."; }
do_start() {
    findmnt -rn "$MOUNT" >/dev/null && umount -l "$MOUNT"
    rmdir "$MOUNT" 2>/dev/null
    echo "$MOUNT nao existe e nada esta montado nele."
}
do_grade() {
    [ -d "$MOUNT" ]; check $? "o ponto de montagem $MOUNT existe"
    linha=$(fstab_line "$MOUNT"); read -r fonte _ tipo opts _ <<< "$linha"
    [ -n "$linha" ] && nfs_src_ok "$fonte" "$EXPORT"; check $? "o /etc/fstab monta $NFS_SERVER:$EXPORT em $MOUNT"
    case "${tipo:-}" in nfs|nfs4) true ;; *) false ;; esac; check $? "a entrada do fstab usa o tipo nfs (atual: ${tipo:-nenhuma})"
    case ",${opts:-}," in *,_netdev,*) true ;; *) false ;; esac; check $? "a entrada do fstab tem a opcao _netdev"
    fonte2=$(findmnt -nro SOURCE "$MOUNT" 2>/dev/null | head -1)
    nfs_src_ok "${fonte2:-}" "$EXPORT"; check $? "o export esta montado agora em $MOUNT (atual: ${fonte2:-nada})"
}
do_finish() {
    findmnt -rn "$MOUNT" >/dev/null && { umount "$MOUNT" 2>/dev/null || umount -l "$MOUNT"; }
    awk -v m="$MOUNT" -v e="$EXPORT" '$1 !~ /^#/ && ($2==m || $1 ~ (":" e "$")){next} {print}' /etc/fstab > "$ST/fstab.novo" && cat "$ST/fstab.novo" > /etc/fstab
    rm -f "${ST:?}/fstab.novo"
    systemctl daemon-reload
    rmdir "$MOUNT" 2>/dev/null
    echo "limpeza: $MOUNT desmontado e fstab sem entradas desse export."
}
run "$@"
