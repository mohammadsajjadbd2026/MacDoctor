#!/bin/bash
# shellcheck shell=bash
# macOS / security updates.

mod_updates() {
  section "১১. সফটওয়্যার আপডেট (Updates)"

  if [ "$QUICK" = "1" ]; then
    info "দ্রুত মোড: আপডেট খোঁজা বাদ"
    return 0
  fi
  info "Apple-এর সার্ভারে আপডেট খোঁজা হচ্ছে…"
  local out
  out=$(with_timeout 300 softwareupdate -l 2>&1)
  detail "$out"

  if printf '%s' "$out" | grep -qi 'No new software available'; then
    ok "macOS আপ-টু-ডেট"
    return 0
  fi
  local labels
  labels=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*\* Label: //p')
  if [ -z "$labels" ]; then
    warn "আপডেট তথ্য পাওয়া যায়নি (ইন্টারনেট আছে তো?)"
    return 0
  fi
  local n
  n=$(printf '%s\n' "$labels" | grep -c .)
  issue "$n টি আপডেট বাকি: $(printf '%s' "$labels" | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
  # Installing can take long and may need a restart, so it is opt-in.
  risky_fix "সব আপডেট ইনস্টল করা (রিস্টার্ট লাগতে পারে, চার্জার লাগিয়ে রাখুন)" \
    softwareupdate -i -a
  advise "রিস্টার্ট দরকার হলে কাজ সেভ করে System Settings → General → Software Update থেকে রিস্টার্ট করুন।"
}
