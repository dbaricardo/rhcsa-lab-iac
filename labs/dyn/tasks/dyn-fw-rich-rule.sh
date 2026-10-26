# Dominio 7 / firewall: regra rich de origem. Params: RULE ZONE
ID=dyn-fw-rich-rule
do_start() {
    fw_save "$ID"; systemctl is-active --quiet firewalld || systemctl start firewalld
    firewall-cmd --permanent --zone="$ZONE" --remove-rich-rule="$RULE" &>/dev/null
    firewall-cmd --reload &>/dev/null
    echo "a regra rich ainda nao existe na zona $ZONE."
}
do_grade() {
    [ "$(firewall-cmd --permanent --zone="$ZONE" --query-rich-rule="$RULE" 2>/dev/null)" = yes ]
    check $? "a regra rich esta na configuracao permanente da zona $ZONE"
    [ "$(firewall-cmd --zone="$ZONE" --query-rich-rule="$RULE" 2>/dev/null)" = yes ]
    check $? "a regra rich esta ativa agora na zona $ZONE (firewall-cmd --reload)"
}
do_finish() { fw_restore "$ID"; echo "limpeza: regras do firewalld restauradas."; }
run "$@"
