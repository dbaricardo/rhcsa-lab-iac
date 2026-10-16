# Dominio 6 / services: servico que nao sobe. Params: SVC SCENARIO(badpath|noexec|baduser|envfile)
ID=dyn-svc-troubleshoot
BIN=/usr/local/bin/${SVC}d
ENVF=/etc/sysconfig/$SVC
GHOST=${SVC}ghost
do_start() {
    unit_purge "$SVC"; rm -f "$BIN" "$ENVF"; id "$GHOST" &>/dev/null && userdel "$GHOST"
    printf '#!/bin/bash\nexec /usr/bin/sleep infinity\n' > "$BIN"; chmod 755 "$BIN"
    case "$SCENARIO" in
        badpath) unit_mk "$SVC" "/usr/local/sbin/${SVC}d" ;;
        noexec)  chmod 644 "$BIN"; unit_mk "$SVC" "$BIN" ;;
        baduser) unit_mk "$SVC" "$BIN" "User=$GHOST" ;;
        envfile) unit_mk "$SVC" "$BIN" "EnvironmentFile=$ENVF" ;;
    esac
    systemctl start "$SVC" &>/dev/null
    echo "o servico $SVC.service falha ao iniciar (defeito: $SCENARIO)."
}
do_grade() {
    [ "$(systemctl is-active "$SVC" 2>/dev/null)" = active ]; check $? "o servico $SVC esta em execucao"
    [ "$(systemctl is-failed "$SVC" 2>/dev/null)" != failed ]; check $? "o servico $SVC nao esta em estado failed"
    sleep 3
    [ "$(systemctl is-active "$SVC" 2>/dev/null)" = active ]; check $? "o servico continua em execucao 3 segundos depois"
}
do_finish() { unit_purge "$SVC"; rm -f "$BIN" "$ENVF"; id "$GHOST" &>/dev/null && userdel "$GHOST"; echo "limpeza: $SVC e arquivos de apoio removidos."; }
run "$@"
