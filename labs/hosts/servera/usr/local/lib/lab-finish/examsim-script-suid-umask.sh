#!/bin/bash
set -u
rm -f /usr/local/bin/newsearch /root/myoutput /usr/local/bin/.examsim14-fallback-suid
rm -rf /tmp/examsim14test
id alex &>/dev/null && userdel -r alex 2>/dev/null
echo "OK: item 14 limpo."
