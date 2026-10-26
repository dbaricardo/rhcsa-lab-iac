#!/bin/bash
# Questao 1 (extra, objetivo Flatpak do RHEL 10): remote de SISTEMA "examrepo"
# apontando pro mirror OSTree do homelab + instalar com.vscodium.codium.
# O lab flatpak-application (cap.07) usa escopo --user e o remote "myrepo";
# aqui e' --system e outro nome de remote para nao colidir com ele.
set -u
grep -qE "^192\.168\.56\.10[[:space:]]+flatpak\.lab\.example\.com" /etc/hosts || echo "192.168.56.10 flatpak.lab.example.com" >> /etc/hosts
flatpak uninstall --system -y --noninteractive com.vscodium.codium &>/dev/null
flatpak remote-delete --system --force examrepo &>/dev/null
flatpak uninstall --system -y --noninteractive --unused &>/dev/null
echo "OK: remote examrepo e com.vscodium.codium removidos do escopo de sistema -- questao 1 pronta."
