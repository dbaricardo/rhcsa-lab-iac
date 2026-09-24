#!/bin/bash
# Não-destrutivo em relação ao ambiente do lab: só executa o próprio script
# que o estudante escreveu (isso É o exercício) em 3 cenários de teste, sem
# alterar nenhum outro estado. timeout evita travar caso o script fique
# esperando entrada em stdin por engano.
set -uo pipefail

STUDENT_HOME="/home/student"
SCRIPT="${STUDENT_HOME}/scripts/relatorio-nomes.sh"
DATA="${STUDENT_HOME}/scripts/dados-nomes.txt"
pass=true

if [ -x "$SCRIPT" ]; then
  echo "OK: ${SCRIPT} existe e é executável"
else
  echo "FALHOU: ${SCRIPT} não existe ou não é executável (chmod +x)"
  echo "RESULTADO: FALHOU"
  exit 0
fi

# Caso 1: sem argumentos -- deve validar e sair com código 1
err1="/tmp/relatorio-nomes-stderr1.$$"
timeout 10 "$SCRIPT" >/dev/null 2>"$err1" </dev/null
rc_noarg=$?
if [ "$rc_noarg" -eq 1 ]; then
  echo "OK: chamado sem argumento, o script sai com código 1"
else
  echo "FALHOU: chamado sem argumento, o script saiu com código ${rc_noarg} (esperado: 1)"
  pass=false
fi
if [ -s "$err1" ]; then
  echo "OK: chamado sem argumento, o script imprime uma mensagem de uso em stderr"
else
  echo "FALHOU: chamado sem argumento, o script não imprime nada em stderr"
  pass=false
fi
rm -f "$err1"

# Caso 2: arquivo inexistente -- deve validar e sair com código 1
err2="/tmp/relatorio-nomes-stderr2.$$"
timeout 10 "$SCRIPT" "/tmp/arquivo-que-nao-existe-relatorio-nomes.$$" >/dev/null 2>"$err2" </dev/null
rc_badfile=$?
if [ "$rc_badfile" -eq 1 ]; then
  echo "OK: chamado com arquivo inexistente, o script sai com código 1"
else
  echo "FALHOU: chamado com arquivo inexistente, o script saiu com código ${rc_badfile} (esperado: 1)"
  pass=false
fi
if [ -s "$err2" ]; then
  echo "OK: chamado com arquivo inexistente, o script imprime uma mensagem de erro em stderr"
else
  echo "FALHOU: chamado com arquivo inexistente, o script não imprime nada em stderr"
  pass=false
fi
rm -f "$err2"

# Caso 3: arquivo válido -- deve processar e sair com código 0
if [ -f "$DATA" ]; then
  out_ok="$(timeout 10 "$SCRIPT" "$DATA" 2>/dev/null </dev/null)"
  rc_ok=$?
  if [ "$rc_ok" -eq 0 ]; then
    echo "OK: chamado com arquivo válido, o script sai com código 0"
  else
    echo "FALHOU: chamado com arquivo válido, o script saiu com código ${rc_ok} (esperado: 0)"
    pass=false
  fi

  missing_name=""
  for nome in Ana Bruno Carla Diego; do
    if ! echo "$out_ok" | grep -q "Processando: ${nome}"; then
      missing_name="$nome"
      break
    fi
  done
  if [ -z "$missing_name" ]; then
    echo "OK: os 4 nomes de ${DATA} foram processados"
  else
    echo "FALHOU: nome '${missing_name}' não apareceu na saída (esperado 'Processando: ${missing_name}')"
    pass=false
  fi

  ultima_linha="$(echo "$out_ok" | tail -n1)"
  if [ "$ultima_linha" = "Total: 4" ]; then
    echo "OK: última linha é exatamente 'Total: 4'"
  else
    echo "FALHOU: última linha não é 'Total: 4' (atual: '${ultima_linha}')"
    pass=false
  fi
else
  echo "FALHOU: arquivo de teste ${DATA} não encontrado (rode 'lab start shell-scripting-01' novamente)"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
