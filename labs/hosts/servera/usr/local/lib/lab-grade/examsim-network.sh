#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

h=$(hostnamectl --static 2>/dev/null)
[ "$h" = "primary.net1.example.com" ]; check $? "hostname e primary.net1.example.com (atual: $h)"

ip=$(nmcli -g IP4.ADDRESS device show ens19 2>/dev/null | head -1 | cut -d/ -f1)
[ "$ip" = "192.168.56.91" ]; check $? "IP de ens19 e 192.168.56.91 (atual: $ip)"

mask=$(nmcli -g IP4.ADDRESS device show ens19 2>/dev/null | head -1 | cut -d/ -f2)
[ "$mask" = "24" ]; check $? "mascara /24 em ens19 (atual: /$mask)"

gw=$(nmcli -g IP4.GATEWAY device show ens19 2>/dev/null)
[ "$gw" = "192.168.56.1" ]; check $? "gateway de ens19 e 192.168.56.1 (atual: $gw)"

dns=$(nmcli -g IP4.DNS device show ens19 2>/dev/null | head -1)
[ -n "$dns" ]; check $? "DNS configurado em ens19 (atual: '$dns')"

# Vincular à origem esperada evita falso positivo via ens18 quando ens19
# está sem endereço, mas ambas pertencem à mesma sub-rede do homelab.
if [ "$ip" = "192.168.56.91" ] && ping -I 192.168.56.91 -c1 -W2 192.168.56.1 &>/dev/null; then
    check 0 "conectividade real via ens19 ate o gateway"
else
    check 1 "conectividade real via ens19 ate o gateway"
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit "$FAIL"
