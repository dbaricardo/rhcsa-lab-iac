#!/bin/bash
# Monta o repositório OSTree "myrepo" do "classroom" (flatpak.lab.example.com)
# a partir do Flathub, do mesmo jeito que o homelab (LXC 205):
#   1. ostree init (archive-z2) + remote "flathub-src" sem verificação GPG;
#   2. pull dos apps e dos runtimes (os que os apps pedem no metadata +
#      a lista fixa do homelab: Platform/Sdk 24.08 e 25.08);
#   3. LIÇÃO DO HOMELAB: o pull deixa os refs só no namespace do remote
#      ("flathub-src:app/..."), e o `flatpak build-update-repo` NÃO indexa
#      esses refs no xa.cache do summary -- sem isso `flatpak remote-ls`/
#      `install` não enxergam nada. Por isso cada ref ganha um alias em
#      refs/heads/ via `ostree refs --create` antes do build-update-repo;
#   4. flatpak build-update-repo (summary + xa.cache + appstream).
#
# Uso: classroom-flatpak-mirror.sh <repo> <url-upstream> <ref-app>... -- <ref-runtime>...
# Idempotente: o pull de um ref já completo só confere o commit; o alias e o
# summary só são refeitos quando algum commit mudou.
# Exige internet (dl.flathub.org). Saída "MUDOU" se algo mudou.
set -euo pipefail

[ "$#" -ge 3 ] || { echo "uso: $0 <repo> <url> <ref-app>... -- <ref-runtime>..." >&2; exit 2; }
REPO="$1"; URL="$2"; shift 2
APPS=(); RUNTIMES=()
alvo=apps
for a in "$@"; do
  if [ "$a" = "--" ]; then alvo=runtimes; continue; fi
  if [ "$alvo" = apps ]; then APPS+=("$a"); else RUNTIMES+=("$a"); fi
done

OST=(ostree --repo="$REPO")
mudou=0

if [ ! -f "$REPO/config" ]; then
  mkdir -p "$REPO"
  "${OST[@]}" init --mode=archive-z2
  mudou=1
fi
if ! "${OST[@]}" remote list | grep -qx flathub-src; then
  "${OST[@]}" remote add --no-gpg-verify flathub-src "$URL"
fi

# pull (no-op barato quando os objetos já estão no repo) + alias em
# refs/heads/ quando o commit mudou. $2 = "opcional": não aborta se o
# Flathub não tiver mais o ref (runtime EOL removido).
espelhar_ref() {
  local ref="$1" opcional="${2:-}" antes depois
  antes="$("${OST[@]}" rev-parse "$ref" 2>/dev/null || true)"
  if ! "${OST[@]}" pull --depth=0 flathub-src "$ref"; then
    if [ -n "$opcional" ]; then
      echo "AVISO: ref opcional indisponível no Flathub: $ref" >&2
      return 0
    fi
    return 1
  fi
  depois="$("${OST[@]}" rev-parse "flathub-src:$ref")"
  [ "$antes" = "$depois" ] && return 0
  "${OST[@]}" refs --delete "$ref" >/dev/null 2>&1 || true
  "${OST[@]}" refs --create="$ref" "$depois"
  mudou=1
}

declare -A runtime_set=()
for ref in "${APPS[@]}"; do
  espelhar_ref "$ref"
  # runtime= e sdk= do metadata do app (ex.: org.freedesktop.Sdk/x86_64/25.08)
  while IFS= read -r r; do
    [ -n "$r" ] && runtime_set["runtime/$r"]=1
  done < <("${OST[@]}" cat "$ref" /metadata | awk -F= '/^(runtime|sdk)=/{print $2}')
done
for ref in "${!runtime_set[@]}"; do
  espelhar_ref "$ref"
  unset 'runtime_set[$ref]'
done
for ref in "${RUNTIMES[@]}"; do
  espelhar_ref "$ref" opcional
done

if [ "$mudou" -eq 1 ] || [ ! -f "$REPO/summary" ]; then
  flatpak build-update-repo "$REPO"
  mudou=1
fi
[ "$mudou" -eq 1 ] && echo "MUDOU"
exit 0
