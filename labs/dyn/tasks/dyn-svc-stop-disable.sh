# Dominio 6 / services: parar e desabilitar. Params: SVC
ID=dyn-svc-stop-disable
do_start() { unit_purge "$SVC"; unit_mk "$SVC" "/usr/bin/sleep infinity"; systemctl enable --now "$SVC" &>/dev/null; echo "o servico $SVC.service esta em execucao e habilitado."; }
do_grade() {
    [ "$(systemctl is-active "$SVC" 2>/dev/null)" != active ]; check $? "o servico $SVC esta parado"
    [ "$(systemctl is-enabled "$SVC" 2>/dev/null)" = disabled ]; check $? "o servico $SVC esta desabilitado no boot"
}
do_finish() { unit_purge "$SVC"; echo "limpeza: $SVC removido."; }
run "$@"
