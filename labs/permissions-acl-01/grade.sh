#!/bin/bash
# Não-destrutivo: só consulta o estado, nunca altera nada.
set -uo pipefail

pass=true
DIR=/dados/projeto-atlas

if getent group projeto-atlas >/dev/null; then
  echo "OK: grupo projeto-atlas existe"
else
  echo "FALHOU: grupo projeto-atlas não existe"
  pass=false
fi

if id carla >/dev/null 2>&1; then
  if id -nG carla | grep -qw projeto-atlas; then
    echo "FALHOU: carla não deveria pertencer ao grupo projeto-atlas (resolva via ACL, não via grupo)"
    pass=false
  else
    echo "OK: carla não pertence ao grupo projeto-atlas"
  fi
else
  echo "FALHOU: usuária carla não existe (rode 'lab start permissions-acl-01' novamente)"
  pass=false
fi

if [ -d "$DIR" ]; then
  echo "OK: diretório ${DIR} existe"

  owner="$(stat -c '%U' "$DIR" 2>/dev/null)"
  group="$(stat -c '%G' "$DIR" 2>/dev/null)"
  if [ "$owner" = "root" ] && [ "$group" = "projeto-atlas" ]; then
    echo "OK: ${DIR} pertence a root:projeto-atlas"
  else
    echo "FALHOU: ${DIR} não pertence a root:projeto-atlas (atual: ${owner:-?}:${group:-?})"
    pass=false
  fi

  perms="$(stat -c '%a' "$DIR" 2>/dev/null)"
  if [ "$perms" = "2770" ]; then
    echo "OK: ${DIR} tem permissões 2770 (SGID habilitado)"
  else
    echo "FALHOU: ${DIR} não tem permissões 2770 (atual: ${perms:-desconhecido})"
    pass=false
  fi

  acl="$(getfacl --omit-header "$DIR" 2>/dev/null)"
  if echo "$acl" | grep -Eq '^user:carla:rw'; then
    echo "OK: ACL concede leitura/escrita a carla em ${DIR}"
  else
    echo "FALHOU: nenhuma ACL de leitura/escrita para carla encontrada em ${DIR}"
    pass=false
  fi

  if echo "$acl" | grep -Eq '^default:user:carla:rw'; then
    echo "OK: ACL padrão (default) concede leitura/escrita a carla para novos arquivos"
  else
    echo "FALHOU: nenhuma ACL padrão (default) para carla encontrada em ${DIR}"
    pass=false
  fi
else
  echo "FALHOU: diretório ${DIR} não existe"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
