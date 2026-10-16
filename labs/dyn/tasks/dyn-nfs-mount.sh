# Dominio 4 / network_storage: mount NFS manual. Params: MOUNT  (servidor: workstation)
ID=dyn-nfs-mount
EXPORT=/exports/dyn-nfsdata
do_server_start() { nfs_export_add nfsmount "$EXPORT"; echo "export $EXPORT pronto na workstation."; }
do_server_finish() { nfs_export_del nfsmount "$EXPORT"; echo "limpeza: export $EXPORT removido."; }
do_start() {
    findmnt -rn "$MOUNT" >/dev/null && umount -l "$MOUNT"
    rmdir "$MOUNT" 2>/dev/null
    echo "$MOUNT nao existe e nada esta montado nele."
}
do_grade() {
    [ -d "$MOUNT" ]; check $? "o ponto de montagem $MOUNT existe"
    read -r fonte tipo opts < <(findmnt -nro SOURCE,FSTYPE,OPTIONS "$MOUNT" 2>/dev/null | head -1)
    case "${tipo:-}" in nfs|nfs4) true ;; *) false ;; esac
    check $? "ha um filesystem NFS montado em $MOUNT (atual: ${tipo:-nada})"
    nfs_src_ok "${fonte:-}" "$EXPORT"; check $? "a origem e $NFS_SERVER:$EXPORT (atual: ${fonte:-nada})"
    case ",${opts:-}," in *,rw,*) true ;; *) false ;; esac; check $? "o mount e leitura e escrita (rw)"
    [ "$(cat "$MOUNT/hello.txt" 2>/dev/null)" = conteudo-dyn-nfsmount ]; check $? "o conteudo do export esta acessivel em $MOUNT"
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
