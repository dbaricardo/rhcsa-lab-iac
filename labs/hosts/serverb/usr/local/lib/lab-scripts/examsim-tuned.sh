#!/bin/bash
# Item 18: profile tuned ativo deve bater com o recomendado.
set -u
rec=$(tuned-adm recommend 2>/dev/null | tr -d '[:space:]')
if [ "$rec" = "balanced" ]; then wrong="virtual-guest"; else wrong="balanced"; fi
tuned-adm profile "$wrong" &>/dev/null
echo "OK: profile forcado para $wrong (recomendado seria $rec) -- item 18 pronto."
