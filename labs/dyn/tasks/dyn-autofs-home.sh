# Dominio 4 / network_storage: autofs de homes com curinga em /home/guests. Sem params
ID=dyn-autofs-home
KEY=autofshome
EXPORT=/exports/dyn-guests
MOUNT=/home/guests
do_server_start() { nfs_export_add "$KEY" "$EXPORT" alice bob carol; echo "export $EXPORT pronto na workstation."; }
do_server_finish() { nfs_export_del "$KEY" "$EXPORT"; echo "limpeza: export $EXPORT removido."; }
do_start() {
    autofs_save "$ID"
    systemctl stop autofs 2>/dev/null
    systemctl reset-failed autofs 2>/dev/null
    rmdir "$MOUNT" 2>/dev/null
    echo "autofs sem configuracao para $MOUNT."
}
do_grade() {
    systemctl is-active --quiet autofs; check $? "o servico autofs esta ativo"
    systemctl is-enabled --quiet autofs; check $? "o servico autofs esta habilitado no boot"
    local u src
    for u in alice bob; do
        timeout 20 bash -c 'ls "$0" >/dev/null 2>&1' "$MOUNT/$u"
        src=$(findmnt -nro SOURCE,FSTYPE "$MOUNT/$u" 2>/dev/null | awk '$2 ~ /^nfs/ {print $1; exit}')
        nfs_src_ok "${src:-}" "$EXPORT/$u"
        check $? "acessar $MOUNT/$u monta $NFS_SERVER:$EXPORT/$u (curinga)"
    done
}
do_finish() {
    autofs_restore "$ID"
    rmdir "$MOUNT" 2>/dev/null
    echo "limpeza: configuracao do autofs restaurada."
}
run "$@"
