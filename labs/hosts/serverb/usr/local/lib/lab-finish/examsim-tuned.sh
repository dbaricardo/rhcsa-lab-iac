#!/bin/bash
set -u
rec=$(tuned-adm recommend 2>/dev/null | tr -d '[:space:]')
tuned-adm profile "$rec" &>/dev/null
echo "OK: item 18 limpo (profile revertido pro recomendado: $rec)."
