#!/bin/bash
# Não-destrutivo: só consulta o estado (--permanent e runtime), nunca altera
# nem recarrega o firewalld.
set -uo pipefail

pass=true
zone="$(firewall-cmd --get-default-zone 2>/dev/null)"

if systemctl is-active --quiet firewalld 2>/dev/null; then
  echo "OK: firewalld está ativo"
else
  echo "FALHOU: firewalld não está ativo"
  pass=false
fi

if firewall-cmd --permanent --get-services 2>/dev/null | tr ' ' '\n' | grep -qx 'coletor-noturno'; then
  echo "OK: serviço customizado 'coletor-noturno' existe (permanente)"

  if firewall-cmd --permanent --service=coletor-noturno --get-ports 2>/dev/null | grep -qw '9090/tcp'; then
    echo "OK: serviço 'coletor-noturno' usa a porta 9090/tcp"
  else
    echo "FALHOU: serviço 'coletor-noturno' não tem a porta 9090/tcp"
    pass=false
  fi
else
  echo "FALHOU: serviço customizado 'coletor-noturno' não existe (firewall-cmd --permanent --new-service)"
  pass=false
fi

if [ -n "$zone" ] && firewall-cmd --permanent --zone="$zone" --list-services 2>/dev/null | tr ' ' '\n' | grep -qx 'coletor-noturno'; then
  echo "OK: 'coletor-noturno' está associado à zona padrão ($zone), de forma permanente"
else
  echo "FALHOU: 'coletor-noturno' não está associado à zona padrão de forma permanente"
  pass=false
fi

if [ -n "$zone" ] && firewall-cmd --permanent --zone="$zone" --list-ports 2>/dev/null | tr ' ' '\n' | grep -qx '9191/tcp'; then
  echo "OK: porta 9191/tcp liberada na zona padrão, de forma permanente"
else
  echo "FALHOU: porta 9191/tcp não está liberada de forma permanente na zona padrão"
  pass=false
fi

if [ -n "$zone" ] \
   && firewall-cmd --zone="$zone" --list-services 2>/dev/null | tr ' ' '\n' | grep -qx 'coletor-noturno' \
   && firewall-cmd --zone="$zone" --list-ports 2>/dev/null | tr ' ' '\n' | grep -qx '9191/tcp'; then
  echo "OK: configuração em runtime bate com a configuração permanente (firewalld foi recarregado)"
else
  echo "FALHOU: configuração em runtime não bate com a permanente -- rode 'firewall-cmd --reload'"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
