# Dominio 2 / journalctl: journal persistente. Sem params.
ID=dyn-journal-persistent
CONF=/etc/systemd/journald.conf
do_start() {
    conf_save "$CONF" "$ID"; dropins_save "$ID"
    [ -e "$ST/$ID.hadir" ] || { [ -d /var/log/journal ] && echo 1 || echo 0; } > "$ST/$ID.hadir"
    [ -e "$CONF" ] && sed -i -E '/^[#[:space:]]*Storage=/d' "$CONF"
    journal_set 'Storage=volatile'
    rm -rf /var/log/journal
    journal_restart
    echo "journal em Storage=volatile e sem /var/log/journal; a questao pede torna-lo persistente."
}
do_grade() {
    st=$(journal_value Storage)
    case "$st" in
        persistent) ok=0 ;;
        auto)       [ -d /var/log/journal ]; ok=$? ;;
        *)          ok=1 ;;
    esac
    check $ok "o journal esta configurado como persistente (Storage atual: ${st:-padrao})"
    systemctl is-active --quiet systemd-journald; check $? "systemd-journald ativo"
}
do_finish() {
    conf_restore "$CONF" "$ID"; dropins_restore "$ID"
    if [ "$(cat "$ST/$ID.hadir" 2>/dev/null)" = 1 ]; then
        mkdir -p /var/log/journal; systemd-tmpfiles --create --prefix /var/log/journal &>/dev/null
    else
        rm -rf /var/log/journal
    fi
    rm -f "$ST/$ID.hadir"
    journal_restart
    echo "limpeza: configuracao original do journald restaurada."
}
run "$@"
