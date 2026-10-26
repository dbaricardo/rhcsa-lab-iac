#!/bin/bash
set -u
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }

grep -rEq 'baseurl=http://content\.example\.com:8091/rhel10\.0/x86_64/dvd/BaseOS/?$' /etc/yum.repos.d/*.repo 2>/dev/null
check $? "algum .repo com baseurl de BaseOS correto (content.example.com:8091/rhel10.0/x86_64/dvd/BaseOS)"

grep -rEq 'baseurl=http://content\.example\.com:8091/rhel10\.0/x86_64/dvd/AppStream/?$' /etc/yum.repos.d/*.repo 2>/dev/null
check $? "algum .repo com baseurl de AppStream correto (content.example.com:8091/rhel10.0/x86_64/dvd/AppStream)"

rpm -q tree &>/dev/null && dnf -y remove tree &>/dev/null
mapfile -t custom_ids < <(awk -F'[][]' '/^\[/{id=$2} /baseurl=http:\/\/content\.example\.com:8091\/rhel10\.0\/x86_64\/dvd\/(BaseOS|AppStream)/{print id}' /etc/yum.repos.d/*.repo 2>/dev/null | sort -u)
enable_args=(--disablerepo='*')
for repo_id in "${custom_ids[@]}"; do enable_args+=(--enablerepo="$repo_id"); done
dnf "${enable_args[@]}" -y install tree &>/dev/null && rpm -q tree &>/dev/null
check $? "dnf install real vem somente dos repos customizados configurados"
dnf -y remove tree &>/dev/null

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
