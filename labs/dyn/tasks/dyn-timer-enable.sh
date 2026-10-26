# Dominio 6 / systemd_timers: habilitar e iniciar um timer existente. Params: NAME
ID=dyn-timer-enable
do_start() {
    unit_purge "$NAME"
    printf '[Unit]\nDescription=Servico de laboratorio %s\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/true\n' "$NAME" > "/etc/systemd/system/$NAME.service"
    printf '[Unit]\nDescription=Timer de laboratorio %s\n\n[Timer]\nOnCalendar=daily\nPersistent=true\n\n[Install]\nWantedBy=timers.target\n' "$NAME" > "/etc/systemd/system/$NAME.timer"
    systemctl daemon-reload
    echo "o timer $NAME.timer existe, esta parado e desabilitado."
}
do_grade() { timer_state_ok "$NAME"; }
do_finish() { unit_purge "$NAME"; echo "limpeza: $NAME removido."; }
run "$@"
