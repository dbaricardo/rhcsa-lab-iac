#!/bin/bash
# Item 3: repositorio BaseOS+AppStream apontando pra content.example.com.
set -u
grep -l 'content.example.com' /etc/yum.repos.d/*.repo 2>/dev/null | xargs -r rm -f
rpm -q tree &>/dev/null && dnf -y remove tree &>/dev/null
echo "OK: sem repo customizado apontando pra content.example.com -- item 17 pronto."
