#!/bin/bash
# Double-click this file in Finder to start MacDoctor.
cd "$(dirname "$0")" || exit 1
clear
/bin/bash ./macdoctor.sh --auto
echo
echo "শেষ! এই উইন্ডো বন্ধ করতে যেকোনো কী চাপুন…"
read -r -n 1 -s
