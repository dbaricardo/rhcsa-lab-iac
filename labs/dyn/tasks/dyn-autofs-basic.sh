# Dominio 4 / network_storage: autofs indireto (curinga) ou direto. Params: MAPTYPE MOUNT EXPORT
ID=dyn-autofs-basic
KEY=autofsbasic
do_server_start() {
    if [ "$MAPTYPE" = indirect ]; then nfs_export_add "$KEY" "$EXPORT" docs tools projects; else nfs_export_add "$KEY" "$EXPORT"; fi
    echo "export $EXPORT pronto na workstation."
}
do_server_finish() { nfs_export_del "$KEY" "$EXPORT"; echo "limpeza: export $EXPORT removido."; }
do_start() {
    autofs_save "$ID"
    systemctl stop autofs 2>/dev/null
    systemctl reset-failed autofs 2>/dev/null
    rmdir "$MOUNT" 2>/dev/null
    echo "autofs sem configuracao para $MOUNT."
}
mounted_from() {  # mounted_from <caminho> <export esperado> -> dispara o automount e confere a origem
    ls "$1" >/dev/null 2>&1
    # num mapa direto o caminho tem 2 mounts empilhados (autofs e NFS): pega o do NFS
    local src; src=$(findmnt -nro SOURCE,FSTYPE "$1" 2>/dev/null | awk '$2 ~ /^nfs/ {print $1; exit}')
    nfs_src_ok "${src:-}" "$2"
}
do_grade() {
    systemctl is-active --quiet autofs; check $? "o servico autofs esta ativo"
    systemctl is-enabled --quiet autofs; check $? "o servico autofs esta habilitado no boot"
    if [ "$MAPTYPE" = indirect ]; then
        timeout 20 bash -c 'ls "$0/docs" >/dev/null 2>&1' "$MOUNT"
        mounted_from "$MOUNT/docs" "$EXPORT/docs"; check $? "acessar $MOUNT/docs monta $NFS_SERVER:$EXPORT/docs"
        timeout 20 bash -c 'ls "$0/tools" >/dev/null 2>&1' "$MOUNT"
        mounted_from "$MOUNT/tools" "$EXPORT/tools"; check $? "o curinga funciona: $MOUNT/tools tambem e montado sob demanda"
    else
        timeout 20 bash -c 'ls "$0" >/dev/null 2>&1' "$MOUNT"
        mounted_from "$MOUNT" "$EXPORT"; check $? "acessar $MOUNT monta $NFS_SERVER:$EXPORT (mapa direto)"
        [ "$(cat "$MOUNT/hello.txt" 2>/dev/null)" = "conteudo-dyn-$KEY" ]; check $? "o conteudo do export esta acessivel em $MOUNT"
    fi
}
do_finish() {
    autofs_restore "$ID"
    rmdir "$MOUNT" 2>/dev/null
    echo "limpeza: configuracao do autofs restaurada."
}
run "$@"
