# Dominio 7 / firewall: abrir porta. Params: PORT PROTO ZONE
ID=dyn-fw-port
PP="$PORT/$PROTO"
do_start() {
    systemctl is-active --quiet firewalld || systemctl enable --now firewalld &>/dev/null
    if [ ! -e "$ST/$ID.orig" ]; then
        p=$(firewall-cmd --permanent --zone="$ZONE" --query-port="$PP" 2>/dev/null)
        r=$(firewall-cmd --zone="$ZONE" --query-port="$PP" 2>/dev/null)
        echo "${p:-no} ${r:-no}" > "$ST/$ID.orig"
    fi
    firewall-cmd --permanent --zone="$ZONE" --remove-port="$PP" &>/dev/null
    firewall-cmd --zone="$ZONE" --remove-port="$PP" &>/dev/null
    echo "porta $PP fechada na zona $ZONE."
}
do_grade() {
    [ "$(firewall-cmd --permanent --zone="$ZONE" --query-port="$PP" 2>/dev/null)" = yes ]
    check $? "porta $PP na configuracao permanente da zona $ZONE"
    [ "$(firewall-cmd --zone="$ZONE" --query-port="$PP" 2>/dev/null)" = yes ]
    check $? "porta $PP ativa agora na zona $ZONE (firewall-cmd --reload)"
}
do_finish() {
    read -r p r < "$ST/$ID.orig" 2>/dev/null || { p=no; r=no; }
    if [ "$p" = yes ]; then firewall-cmd --permanent --zone="$ZONE" --add-port="$PP" &>/dev/null
    else firewall-cmd --permanent --zone="$ZONE" --remove-port="$PP" &>/dev/null; fi
    if [ "$r" = yes ]; then firewall-cmd --zone="$ZONE" --add-port="$PP" &>/dev/null
    else firewall-cmd --zone="$ZONE" --remove-port="$PP" &>/dev/null; fi
    rm -f "$ST/$ID.orig"
    echo "limpeza: porta $PP na zona $ZONE restaurada."
}
run "$@"
