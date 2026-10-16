# Dominio 6 / services: iniciar sem habilitar (unidade de laboratorio). Params: SVC
ID=dyn-svc-start
do_start() { unit_purge "$SVC"; unit_mk "$SVC" "/usr/bin/sleep infinity"; echo "o servico $SVC.service esta parado e desabilitado."; }
do_grade() {
    [ "$(systemctl is-active "$SVC" 2>/dev/null)" = active ]; check $? "o servico $SVC esta em execucao"
    [ "$(systemctl is-enabled "$SVC" 2>/dev/null)" != enabled ]; check $? "o servico $SVC NAO foi habilitado no boot (so era para iniciar)"
}
do_finish() { unit_purge "$SVC"; echo "limpeza: $SVC removido."; }
run "$@"
