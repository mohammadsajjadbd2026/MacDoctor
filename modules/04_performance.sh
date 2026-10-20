#!/bin/bash
# shellcheck shell=bash
# Memory pressure, swap, CPU hogs.

mod_performance() {
  section "৪. গতি, মেমোরি ও CPU (Performance)"

  if have memory_pressure; then
    local free_pct
    free_pct=$(memory_pressure -Q 2>/dev/null | awk -F: '/percentage/ {gsub(/[ %]/, "", $2); print $2}')
    if [ -n "$free_pct" ]; then
      info "ফাঁকা মেমোরি: ${free_pct}%"
      if [ "$free_pct" -lt 15 ]; then
        issue "মেমোরি প্রায় শেষ (${free_pct}% ফাঁকা)"
        safe_fix "অব্যবহৃত (inactive) মেমোরি খালি করা" purge
        advise "অনেক Chrome ট্যাব/অ্যাপ খোলা থাকলে বন্ধ করুন।"
      else
        ok "মেমোরি স্বাভাবিক"
      fi
    fi
  fi

  local swap_used
  swap_used=$(sysctl -n vm.swapusage 2>/dev/null | sed -E 's/.*used = ([0-9.]+)M.*/\1/')
  if [ -n "$swap_used" ]; then
    info "Swap ব্যবহার: ${swap_used} MB"
    if [ "${swap_used%.*}" -gt 4096 ] 2>/dev/null; then
      issue "Swap অনেক বেশি (${swap_used} MB) — RAM-এর চেয়ে বেশি কাজ চলছে"
      advise "রিস্টার্ট করলে swap খালি হয়ে যাবে।"
    fi
  fi

  # Sample CPU twice so a momentary spike is not reported.
  info "CPU ব্যবহার পরীক্ষা হচ্ছে…"
  local s1 s2
  s1=$(ps -Aco pid=,pcpu=,comm= -r | head -n 15)
  sleep 5
  s2=$(ps -Aco pid=,pcpu=,comm= -r | head -n 15)
  detail "শীর্ষ CPU প্রসেস:"$'\n'"$s2"

  local pid cpu name
  while read -r pid cpu name; do
    [ -z "$pid" ] && continue
    if [ "${cpu%.*}" -ge 80 ] 2>/dev/null && printf '%s\n' "$s1" | awk -v p="$pid" '$1 == p && $2 >= 80 {f=1} END {exit !f}'; then
      case "$name" in
        kernel_task)
          issue "kernel_task অনেক CPU নিচ্ছে (${cpu}%) — সাধারণত Mac অতিরিক্ত গরম হলে হয়"
          advise "ভেন্ট পরিষ্কার রাখুন, শক্ত সমতলে রাখুন; সমস্যা থাকলে SMC রিসেট করুন (docs/KEY_COMBOS.md)।" ;;
        mds|mds_stores|mdworker*)
          info "Spotlight ইনডেক্স করছে ($name) — আপডেট/রিস্টার্টের পর কিছুক্ষণ এমন হওয়া স্বাভাবিক" ;;
        *)
          issue "'$name' (PID $pid) টানা ${cpu}% CPU ব্যবহার করছে"
          advise "'$name' অ্যাপটি বন্ধ করে আবার খুলুন বা আপডেট করুন (Activity Monitor থেকে Quit করা যায়)।" ;;
      esac
    fi
  done <<EOF
$s2
EOF
  ok "CPU পরীক্ষা শেষ"
}
