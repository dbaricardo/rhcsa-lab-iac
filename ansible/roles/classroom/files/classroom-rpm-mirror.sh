#!/bin/bash
# Monta o mirror PARCIAL de BaseOS/AppStream do "classroom" (mesmos NOMES de
# pacote do mirror do homelab, LXC 205) a partir da DVD ISO servida por HTTP
# pelo host (scripts/offline-repo.sh) e gera o repodata com createrepo_c.
#
# Uso: classroom-rpm-mirror.sh <url-da-iso> <destino> <lista-baseos> <lista-appstream>
#   <destino>/BaseOS e <destino>/AppStream recebem os RPMs (um nome por
#   linha nas listas). Idempotente: nome já presente no destino é pulado.
# Saída: "AUSENTE: <nome>" para cada nome que a ISO não tem (não é erro);
# "MUDOU" se baixou algo ou regenerou o repodata.
set -euo pipefail

[ "$#" -eq 4 ] || { echo "uso: $0 <url-iso> <destino> <lista-baseos> <lista-appstream>" >&2; exit 2; }
ISO_URL="${1%/}"
DEST="$2"
LIST_BASEOS="$3"
LIST_APPSTREAM="$4"

mudou=0
DNF=(dnf -q --disablerepo='*'
     --repofrompath="classroom-iso-baseos,${ISO_URL}/BaseOS"
     --repofrompath="classroom-iso-appstream,${ISO_URL}/AppStream"
     --setopt=classroom-iso-baseos.gpgcheck=0
     --setopt=classroom-iso-appstream.gpgcheck=0)

# Nomes já presentes num diretório (pelo cabeçalho do RPM, não pelo nome do
# arquivo: "git" e "git-core" teriam o mesmo prefixo).
nomes_presentes() {
  local dir="$1" f
  for f in "$dir"/*.rpm; do
    [ -e "$f" ] || continue
    rpm -qp --nosignature --qf '%{NAME}\n' "$f" 2>/dev/null
  done | sort -u
}

espelhar() {
  local lista="$1" dir="$2" nome presentes
  mkdir -p "$dir"
  presentes="$(nomes_presentes "$dir")"
  while IFS= read -r nome; do
    nome="${nome%%#*}"; nome="${nome//[[:space:]]/}"
    [ -n "$nome" ] || continue
    if grep -qxF "$nome" <<<"$presentes"; then
      continue
    fi
    if "${DNF[@]}" download --arch=x86_64,noarch --destdir="$dir" "$nome" >/dev/null 2>&1 \
       && nomes_presentes "$dir" | grep -qxF "$nome"; then
      mudou=1
    else
      echo "AUSENTE: $nome"
    fi
  done <"$lista"
  if [ "$mudou" -eq 1 ] || [ ! -f "$dir/repodata/repomd.xml" ]; then
    createrepo_c --quiet --update "$dir" >/dev/null
    mudou=1
  fi
}

espelhar "$LIST_BASEOS" "$DEST/BaseOS"
espelhar "$LIST_APPSTREAM" "$DEST/AppStream"
[ "$mudou" -eq 1 ] && echo "MUDOU"
exit 0
