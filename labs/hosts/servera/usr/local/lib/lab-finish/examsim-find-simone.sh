#!/bin/bash
set -u
id Simone &>/dev/null && userdel -r Simone 2>/dev/null
rm -rf /tmp/examsim10 /var/tmp/examsim10 /opt/examsim10 /root/found
echo "OK: item 10 limpo."
