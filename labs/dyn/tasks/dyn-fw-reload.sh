# Dominio 7 / firewall: regra permanente que nao foi recarregada. Params: SERVICE
ID=dyn-fw-reload
do_start() {
    fw_save "$ID"; systemctl is-active --quiet firewalld || systemctl start firewalld
    firewall-cmd --remove-service="$SERVICE" &>/dev/null
    firewall-cmd --permanent --add-service="$SERVICE" &>/dev/null
    echo "$SERVICE esta so' na configuracao permanente (falta o reload)."
}
do_grade() {
    [ "$(systemctl is-active firewalld 2>/dev/null)" = active ]; check $? "o firewalld esta em execucao"
    [ "$(firewall-cmd --query-service="$SERVICE" 2>/dev/null)" = yes ]; check $? "$SERVICE esta ativo agora (as regras permanentes foram aplicadas)"
    [ "$(firewall-cmd --permanent --query-service="$SERVICE" 2>/dev/null)" = yes ]; check $? "$SERVICE continua na configuracao permanente"
}
do_finish() { fw_restore "$ID"; echo "limpeza: configuracao do firewalld restaurada."; }
run "$@"
