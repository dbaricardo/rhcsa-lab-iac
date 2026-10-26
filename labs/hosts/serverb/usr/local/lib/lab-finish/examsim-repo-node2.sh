#!/bin/bash
set -u
grep -l 'content.example.com' /etc/yum.repos.d/*.repo 2>/dev/null | xargs -r rm -f
rpm -q tree &>/dev/null && dnf -y remove tree &>/dev/null
echo "OK: item 17 limpo."
