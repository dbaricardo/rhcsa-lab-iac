#!/bin/bash
set -u
id barry &>/dev/null && userdel -r barry 2>/dev/null
echo "OK: item 13 limpo."
