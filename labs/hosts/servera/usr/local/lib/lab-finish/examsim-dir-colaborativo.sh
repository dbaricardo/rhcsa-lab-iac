#!/bin/bash
set -u
rm -rf /common/admin
rmdir /common 2>/dev/null || true
id examsim6tester &>/dev/null && userdel examsim6tester 2>/dev/null
echo "OK: item 6 limpo (somente /common/admin; dados irmãos preservados)."
