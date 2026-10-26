# Dominio 6 / services: habilitar no boot. Params: SVC
ID=dyn-svc-enable
do_start() { unit_purge "$SVC"; unit_mk "$SVC" "/usr/bin/sleep infinity"; echo "o servico $SVC.service esta parado e desabilitado."; }
do_grade() { [ "$(systemctl is-enabled "$SVC" 2>/dev/null)" = enabled ]; check $? "o servico $SVC esta habilitado no boot"; }
do_finish() { unit_purge "$SVC"; echo "limpeza: $SVC removido."; }
run "$@"
