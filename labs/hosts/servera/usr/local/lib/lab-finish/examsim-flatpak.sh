#!/bin/bash
set -u
flatpak uninstall --system -y --noninteractive com.vscodium.codium &>/dev/null
flatpak remote-delete --system --force examrepo &>/dev/null
flatpak uninstall --system -y --noninteractive --unused &>/dev/null
echo "OK: questao 1 limpa (app, remote examrepo e runtimes sem uso removidos)."
