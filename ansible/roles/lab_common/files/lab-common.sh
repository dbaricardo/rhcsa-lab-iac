#!/bin/bash
# Helpers compartilhados por qualquer script de lab que toque disco.
# Regra de ouro (bug já descoberto múltiplas vezes em produção real): NUNCA
# referenciar /dev/sdb ou /dev/sdc por nome fixo -- a ordem de enumeração dos
# discos extra pode inverter entre boots. Sempre resolver por tamanho,
# excluindo explicitamente o disco que carrega a raiz.
#
# Uso: source /usr/local/lib/lab-common.sh no início do script.

disco_do_so() {
  # -r = raw (sem caracteres de árvore como "└─"), -s = ordem de dependência,
  # -p = path completo. Sem -r, o nome vem com prefixo de árvore e nenhuma
  # comparação de string bate -- este é exatamente o bug já documentado.
  lsblk -nsrpo NAME "$(findmnt -no SOURCE /)" | tail -n1
}

# resolve_disco <tamanho_esperado_gb> [tolerancia_gb=1]
# Imprime o path do primeiro disco (sem partições, sem ser o disco do SO)
# cujo tamanho bata com o esperado dentro da tolerância. Retorna 1 se nenhum
# disco compatível for encontrado.
resolve_disco() {
  local esperado_gb="${1:?uso: resolve_disco <tamanho_gb> [tolerancia_gb]}"
  local tolerancia_gb="${2:-1}"
  local disco_so
  disco_so="$(disco_do_so)"

  while read -r name size_bytes; do
    local path="/dev/${name}"
    [ "$path" = "$disco_so" ] && continue
    # Ignora discos que já têm partições/filhos (não é um disco "cru").
    [ "$(lsblk -nrpo NAME "$path" | wc -l)" -eq 1 ] || continue
    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
    local diff=$(((size_gb > esperado_gb) ? (size_gb - esperado_gb) : (esperado_gb - size_gb)))
    if [ "$diff" -le "$tolerancia_gb" ]; then
      echo "$path"
      return 0
    fi
  done < <(lsblk -nrbo NAME,SIZE,TYPE | awk '$3=="disk"{print $1, $2}')

  return 1
}

# disco_por_tamanho <tamanho_esperado_gb> [tolerancia_gb=1]
# Igual a resolve_disco(), mas SEM exigir que o disco esteja cru (sem
# partições). Use em finish.sh/cleanup para reencontrar um disco que o
# próprio exercício já particionou -- resolve_disco() não serve aí, porque
# ela existe justamente para IGNORAR discos com partições (uso em start.sh,
# ao escolher um disco cru para o exercício usar). Chamar resolve_disco() de
# novo depois de particionar o disco sempre retorna vazio silenciosamente.
disco_por_tamanho() {
  local esperado_gb="${1:?uso: disco_por_tamanho <tamanho_gb> [tolerancia_gb]}"
  local tolerancia_gb="${2:-1}"
  local disco_so
  disco_so="$(disco_do_so)"

  while read -r name size_bytes; do
    local path="/dev/${name}"
    [ "$path" = "$disco_so" ] && continue
    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
    local diff=$(((size_gb > esperado_gb) ? (size_gb - esperado_gb) : (esperado_gb - size_gb)))
    if [ "$diff" -le "$tolerancia_gb" ]; then
      echo "$path"
      return 0
    fi
  done < <(lsblk -nrbo NAME,SIZE,TYPE | awk '$3=="disk"{print $1, $2}')

  return 1
}
