# Dominio 6 / systemd_timers: listar os timers e salvar. Params: NAME OUTFILE
ID=dyn-timer-list
do_start() {
    unit_purge "$NAME"; safe_rm "$OUTFILE"
    printf '[Unit]\nDescription=Servico de laboratorio %s\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/true\n' "$NAME" > "/etc/systemd/system/$NAME.service"
    printf '[Unit]\nDescription=Timer de laboratorio %s\n\n[Timer]\nOnCalendar=hourly\n\n[Install]\nWantedBy=timers.target\n' "$NAME" > "/etc/systemd/system/$NAME.timer"
    systemctl daemon-reload; systemctl enable --now "$NAME.timer" &>/dev/null
    echo "o timer $NAME.timer esta ativo; $OUTFILE nao existe."
}
do_grade() {
    [ -s "$OUTFILE" ]; check $? "o arquivo $OUTFILE existe e nao esta vazio"
    head -1 "$OUTFILE" 2>/dev/null | grep -q 'NEXT' && head -1 "$OUTFILE" 2>/dev/null | grep -q 'LAST'
    check $? "a listagem tem as colunas NEXT e LAST (horarios da proxima e da ultima execucao)"
    grep -qF "$NAME.timer" "$OUTFILE" 2>/dev/null; check $? "a listagem inclui o timer $NAME.timer"
}
do_finish() { unit_purge "$NAME"; safe_rm "$OUTFILE"; echo "limpeza: $NAME e $OUTFILE removidos."; }
run "$@"
