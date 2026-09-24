#!/bin/bash
# Não-destrutivo: só consulta o estado, nunca altera nada.
set -uo pipefail

pass=true

if getent group equipe-suporte >/dev/null; then
  echo "OK: grupo equipe-suporte existe"
else
  echo "FALHOU: grupo equipe-suporte não existe"
  pass=false
fi

if id ana >/dev/null 2>&1; then
  echo "OK: usuário ana existe"

  if id -nG ana | grep -qw equipe-suporte; then
    echo "OK: ana pertence a equipe-suporte"
  else
    echo "FALHOU: ana não pertence a equipe-suporte"
    pass=false
  fi

  shell_ana="$(getent passwd ana | cut -d: -f7)"
  if [ "$shell_ana" = "/bin/bash" ]; then
    echo "OK: ana tem shell /bin/bash"
  else
    echo "FALHOU: ana não tem shell /bin/bash (atual: ${shell_ana:-ausente})"
    pass=false
  fi

  max_days="$(chage -l ana 2>/dev/null | awk -F': ' '/Maximum number of days/{print $2}')"
  if [ "$max_days" = "90" ]; then
    echo "OK: senha de ana expira a cada 90 dias"
  else
    echo "FALHOU: senha de ana não está configurada para expirar em 90 dias (atual: ${max_days:-desconhecido})"
    pass=false
  fi
else
  echo "FALHOU: usuário ana não existe"
  pass=false
fi

if id bruno >/dev/null 2>&1; then
  echo "OK: usuário bruno existe"

  shell_bruno="$(getent passwd bruno | cut -d: -f7)"
  if [[ "$shell_bruno" == *nologin* ]]; then
    echo "OK: bruno não tem shell interativo"
  else
    echo "FALHOU: bruno tem shell interativo (${shell_bruno:-desconhecido})"
    pass=false
  fi

  if id -nG bruno | grep -qw equipe-suporte; then
    echo "FALHOU: bruno não deveria pertencer a equipe-suporte"
    pass=false
  else
    echo "OK: bruno não pertence a equipe-suporte"
  fi
else
  echo "FALHOU: usuário bruno não existe"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
