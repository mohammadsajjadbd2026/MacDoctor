#!/bin/bash
# shellcheck shell=bash
# Kernel panics and app crashes from the last weeks.

mod_crashes() {
  section "৭. ক্র্যাশ ও কার্নেল প্যানিক (Crashes)"

  local panics count latest
  panics=$(find /Library/Logs/DiagnosticReports -maxdepth 2 -type f \
             \( -name '*.panic' -o -name 'panic-*' -o -name 'Kernel*' \) -mtime -30 2>/dev/null)
  count=$(printf '%s' "$panics" | grep -c . )
  if [ "$count" -eq 0 ]; then
    ok "গত ৩০ দিনে কোনো kernel panic (হঠাৎ রিস্টার্ট) হয়নি"
  else
    issue "গত ৩০ দিনে $count বার kernel panic (হঠাৎ রিস্টার্ট) হয়েছে"
    latest=$(printf '%s\n' "$panics" | tr '\n' '\0' | xargs -0 ls -t 2>/dev/null | head -n 1)
    if [ -n "$latest" ]; then
      local reason
      reason=$(grep -m1 -oE 'panic\([^)]*\)[^\\"]{0,160}' "$latest" 2>/dev/null)
      [ -n "$reason" ] && info "শেষ কারণ: $reason"
      detail "শেষ panic ফাইল: $latest"
    fi
    advise "বারবার panic হলে: macOS আপডেট করুন, থার্ড-পার্টি kext/অ্যান্টিভাইরাস সরান, NVRAM ও SMC রিসেট করুন, তারপর Apple Diagnostics (চালুর সময় D চেপে ধরে) চালান।"
  fi

  local dirs="/Library/Logs/DiagnosticReports"
  [ -n "$USER_HOME" ] && dirs="$USER_HOME/Library/Logs/DiagnosticReports $dirs"
  local top
  # shellcheck disable=SC2086
  top=$(find $dirs -maxdepth 1 -type f \( -name '*.crash' -o -name '*.ips' \) -mtime -7 2>/dev/null |
        sed -E 's#.*/##; s/[-_][0-9]{4}-[0-9]{2}-[0-9]{2}.*//' |
        grep -viE '^(panic|JetsamEvent|ExcUserFault|.*\.diag)' |
        sort | uniq -c | sort -rn | head -n 5)
  if [ -z "$top" ]; then
    ok "গত ৭ দিনে কোনো অ্যাপ ক্র্যাশ নেই"
    return 0
  fi
  detail "গত ৭ দিনের ক্র্যাশ:"$'\n'"$top"
  local n app
  while read -r n app; do
    [ -z "$app" ] && continue
    if [ "$n" -ge 3 ]; then
      issue "'$app' গত ৭ দিনে $n বার ক্র্যাশ করেছে"
      advise "'$app' আপডেট বা রিইনস্টল করুন।"
    else
      info "'$app' $n বার ক্র্যাশ করেছে"
    fi
  done <<EOF
$top
EOF
}
