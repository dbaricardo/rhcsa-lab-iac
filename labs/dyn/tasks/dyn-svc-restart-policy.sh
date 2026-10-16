# Dominio 6 / services: drop-in com Restart=always e RestartSec. Params: SVC RESTARTSEC
ID=dyn-svc-restart-policy
do_start() { unit_purge "$SVC"; unit_mk "$SVC" "/usr/bin/sleep infinity"; systemctl start "$SVC"; echo "o servico $SVC.service esta em execucao, sem politica de reinicio."; }
do_grade() {
    local d=/etc/systemd/system/$SVC.service.d
    [ -d "$d" ]; check $? "o diretorio de drop-in $d existe"
    grep -qsE '^[[:space:]]*Restart=always' "$d"/*.conf; check $? "Restart=always esta num arquivo .conf do drop-in"
    grep -qsE "^[[:space:]]*RestartSec=($RESTARTSEC|${RESTARTSEC}s)[[:space:]]*$" "$d"/*.conf; check $? "RestartSec=$RESTARTSEC esta no drop-in"
    [ "$(systemctl show "$SVC" -p Restart --value 2>/dev/null)" = always ]; check $? "o systemd informa Restart=always (daemon-reload feito)"
    [ "$(systemctl show "$SVC" -p RestartUSec --value 2>/dev/null)" = "${RESTARTSEC}s" ]; check $? "o systemd informa RestartUSec=${RESTARTSEC}s"
    [ "$(systemctl is-active "$SVC" 2>/dev/null)" = active ]; check $? "o servico $SVC esta em execucao"
    local pid novo
    pid=$(systemctl show "$SVC" -p MainPID --value 2>/dev/null)
    if [ -n "$pid" ] && [ "$pid" != 0 ]; then
        kill -9 "$pid" 2>/dev/null
        sleep $((RESTARTSEC + 3))
        novo=$(systemctl show "$SVC" -p MainPID --value 2>/dev/null)
        [ "$(systemctl is-active "$SVC" 2>/dev/null)" = active ] && [ -n "$novo" ] && [ "$novo" != 0 ] && [ "$novo" != "$pid" ]
        check $? "teste real: matar o processo principal faz o systemd reinicia-lo em ~${RESTARTSEC}s"
    else check 1 "teste real: o servico tem um processo principal para o teste"; fi
}
do_finish() { unit_purge "$SVC"; echo "limpeza: $SVC e o drop-in removidos."; }
run "$@"
