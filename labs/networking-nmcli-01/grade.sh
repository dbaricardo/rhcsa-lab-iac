#!/bin/bash
# Não-destrutivo: só consulta o estado (nmcli ... show), nunca altera nem
# ativa nenhuma conexão -- evita qualquer risco à sessão SSH atual.
set -uo pipefail

pass=true
PROFILE="perfil-backup"

if nmcli -g NAME connection show 2>/dev/null | grep -qx "$PROFILE"; then
  echo "OK: perfil de conexão '$PROFILE' existe"

  con_type="$(nmcli -g connection.type connection show "$PROFILE" 2>/dev/null)"
  if [ "$con_type" = "802-3-ethernet" ] || [ "$con_type" = "ethernet" ]; then
    echo "OK: '$PROFILE' é do tipo ethernet"
  else
    echo "FALHOU: '$PROFILE' não é do tipo ethernet (atual: ${con_type:-desconhecido})"
    pass=false
  fi

  ifname="$(nmcli -g connection.interface-name connection show "$PROFILE" 2>/dev/null)"
  if [ "$ifname" = "eth1" ]; then
    echo "OK: '$PROFILE' está associado à interface lógica 'eth1'"
  else
    echo "FALHOU: '$PROFILE' não está associado à interface 'eth1' (atual: ${ifname:-nenhuma})"
    pass=false
  fi

  ipv4_method="$(nmcli -g ipv4.method connection show "$PROFILE" 2>/dev/null)"
  if [ "$ipv4_method" = "manual" ]; then
    echo "OK: IPv4 configurado como estático (manual)"
  else
    echo "FALHOU: IPv4 não está configurado como estático (atual: ${ipv4_method:-desconhecido})"
    pass=false
  fi

  ipv4_addr="$(nmcli -g ipv4.addresses connection show "$PROFILE" 2>/dev/null)"
  if echo "$ipv4_addr" | grep -q '192\.168\.100\.50/24'; then
    echo "OK: endereço IPv4 192.168.100.50/24 configurado"
  else
    echo "FALHOU: endereço IPv4 esperado não encontrado (atual: ${ipv4_addr:-nenhum})"
    pass=false
  fi

  ipv4_gw="$(nmcli -g ipv4.gateway connection show "$PROFILE" 2>/dev/null)"
  if [ "$ipv4_gw" = "192.168.100.1" ]; then
    echo "OK: gateway 192.168.100.1 configurado"
  else
    echo "FALHOU: gateway esperado não encontrado (atual: ${ipv4_gw:-nenhum})"
    pass=false
  fi

  ipv4_dns="$(nmcli -g ipv4.dns connection show "$PROFILE" 2>/dev/null)"
  if echo "$ipv4_dns" | grep -q '192\.168\.100\.1'; then
    echo "OK: DNS 192.168.100.1 configurado"
  else
    echo "FALHOU: DNS esperado não encontrado (atual: ${ipv4_dns:-nenhum})"
    pass=false
  fi

  if nmcli -t -f NAME connection show --active 2>/dev/null | grep -qx "$PROFILE"; then
    echo "FALHOU: '$PROFILE' está ativo -- deveria permanecer apenas configurado (não use 'nmcli connection up')"
    pass=false
  else
    echo "OK: '$PROFILE' não está ativo, como esperado"
  fi
else
  echo "FALHOU: perfil de conexão '$PROFILE' não existe"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
