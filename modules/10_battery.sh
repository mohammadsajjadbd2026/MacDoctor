#!/bin/bash
# shellcheck shell=bash
# Battery health and heat.

mod_battery() {
  section "১০. ব্যাটারি ও তাপমাত্রা (Battery)"

  local p cycles cond
  p=$(system_profiler SPPowerDataType 2>/dev/null)
  cycles=$(printf '%s\n' "$p" | awk -F: '/Cycle Count/ {gsub(/ /, "", $2); print $2; exit}')
  cond=$(printf '%s\n' "$p" | awk -F: '/Condition/ {gsub(/^ +/, "", $2); print $2; exit}')

  if [ -z "$cycles$cond" ]; then
    info "ব্যাটারি পাওয়া যায়নি"
  else
    info "ব্যাটারি চার্জ সাইকেল: ${cycles:-?} / 1000   অবস্থা: ${cond:-?}"
    case "$cond" in
      Normal|"") ;;
      *) issue "ব্যাটারির অবস্থা: $cond"
         advise "ব্যাটারি বদলানো দরকার হতে পারে। ট্র্যাকপ্যাড উঁচু হয়ে গেলে বা কেস ফুলে গেলে সাথে সাথে চার্জ দেওয়া বন্ধ করে সার্ভিসে নিন।" ;;
    esac
    if [ -n "$cycles" ] && [ "$cycles" -ge 1000 ] 2>/dev/null; then
      issue "ব্যাটারি ১০০০ সাইকেল পার করেছে — Apple-এর হিসাবে আয়ু শেষ"
    fi
  fi

  local therm
  therm=$(pmset -g therm 2>/dev/null)
  if printf '%s' "$therm" | grep -qiE 'CPU_Speed_Limit[[:space:]]*=[[:space:]]*[0-8]?[0-9]$'; then
    issue "অতিরিক্ত গরমের কারণে CPU-র গতি কমিয়ে দেওয়া হয়েছে"
    advise "Mac শক্ত সমতলে রাখুন, ভেন্টের ধুলো পরিষ্কার করুন; ফ্যান বেশি শব্দ করলে SMC রিসেট করুন।"
  else
    ok "তাপমাত্রার কারণে কোনো গতি-সীমা নেই"
  fi
  detail "$therm"
}
