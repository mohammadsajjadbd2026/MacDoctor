#!/bin/bash
# shellcheck shell=bash
# Disk health, free space, file-system verification.

mod_disk() {
  section "২. ডিস্ক ও স্টোরেজ (Disk)"

  local dinfo smart
  dinfo=$(diskutil info / 2>/dev/null)
  smart=$(printf '%s\n' "$dinfo" | awk -F: '/SMART Status/ {gsub(/^ +/, "", $2); print $2}')
  case "$smart" in
    Verified) ok "SSD SMART স্ট্যাটাস: Verified (হার্ডওয়্যার ঠিক আছে)" ;;
    "")       info "SMART স্ট্যাটাস পাওয়া যায়নি" ;;
    *)        issue "SSD SMART স্ট্যাটাস: $smart — ডিস্ক নষ্ট হতে পারে!"
              advise "এখনই Time Machine বা বাইরের ড্রাইভে সব ফাইলের ব্যাকআপ নিন এবং Apple Service-এ দেখান।" ;;
  esac

  # Free space
  local total free pct
  total=$(df -k / | awk 'NR==2 {print $2 * 1024}')
  free=$(free_bytes)
  if [ -n "$total" ] && [ "$total" -gt 0 ]; then
    pct=$(( free * 100 / total ))
    info "ফাঁকা জায়গা: $(human "$free") / $(human "$total") (${pct}%)"
    if [ "$pct" -lt 10 ] || [ "$free" -lt 21474836480 ]; then
      issue "ডিস্কে জায়গা কম (${pct}%) — macOS ধীর হয়, আপডেট আটকে যায়"
      if have tmutil; then
        # Local Time Machine snapshots can hold tens of GB; macOS recreates them.
        safe_fix "পুরনো লোকাল Time Machine snapshot মুছে জায়গা খালি করা" \
          tmutil thinlocalsnapshots / 999999999999 4
      fi
      advise "Downloads ফোল্ডার ও বড় ফাইল দেখুন:  Apple মেনু → About This Mac → Storage → Manage"
    else
      ok "যথেষ্ট ফাঁকা জায়গা আছে"
    fi
  fi

  # File-system check of the running system (APFS supports live verify).
  if [ "$QUICK" = "1" ]; then
    info "দ্রুত মোড: ডিস্ক verify বাদ দেওয়া হলো"
    return 0
  fi
  info "ফাইল সিস্টেম যাচাই হচ্ছে (কয়েক মিনিট লাগতে পারে)…"
  local vout
  if vout=$(with_timeout 900 diskutil verifyVolume / 2>&1); then
    ok "ফাইল সিস্টেম ঠিক আছে"
  else
    if printf '%s' "$vout" | grep -qiE 'corrupt|invalid|error|needs to be repaired'; then
      issue "ফাইল সিস্টেমে ত্রুটি পাওয়া গেছে"
      advise "Recovery Mode-এ ঢুকে (চালু করার সময় ⌘+R) Terminal থেকে USB-এর recovery/recovery-repair.sh চালান — চলমান সিস্টেম ডিস্ক রিপেয়ার করা যায় না।"
    else
      warn "verify শেষ করা যায়নি (চলমান ডিস্কে মাঝে মাঝে হয়) — বিস্তারিত রিপোর্টে"
    fi
  fi
  detail "$vout"
}
