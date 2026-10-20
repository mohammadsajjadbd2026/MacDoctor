#!/bin/bash
# shellcheck shell=bash
# Common macOS glitches: Spotlight, "Open With" menu, fonts, clock, Finder/Dock.

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

mod_services() {
  section "৮. macOS সার্ভিস (Spotlight, ঘড়ি, Finder)"

  # Clock: wrong time breaks HTTPS, iCloud and App Store.
  if have systemsetup; then
    local nt
    nt=$(systemsetup -getusingnetworktime 2>/dev/null)
    case "$nt" in
      *On*)  ok "স্বয়ংক্রিয় সময় চালু আছে" ;;
      *Off*) issue "স্বয়ংক্রিয় সময় বন্ধ — ভুল সময় থাকলে ওয়েবসাইট/App Store কাজ করে না"
             safe_fix "স্বয়ংক্রিয় সময় চালু করা" systemsetup -setusingnetworktime on ;;
    esac
  fi

  # Spotlight
  local md
  md=$(mdutil -s / 2>/dev/null | tail -n 1)
  case "$md" in
    *enabled*) ok "Spotlight ইনডেক্সিং চালু" ;;
    *disabled*)
      issue "Spotlight ইনডেক্সিং বন্ধ — সার্চ কাজ করবে না"
      safe_fix "Spotlight ইনডেক্সিং চালু করা" mdutil -i on / ;;
    *) warn "Spotlight অবস্থা: ${md:-অজানা}" ;;
  esac
  risky_fix "Spotlight ইনডেক্স নতুন করে তৈরি (সার্চে ফাইল না এলে; কয়েক ঘণ্টা CPU চলবে)" mdutil -E /

  # LaunchServices: duplicate "Open With" entries, wrong default apps.
  if [ -x "$LSREGISTER" ]; then
    risky_fix "'Open With' মেনু ও ডিফল্ট অ্যাপ ডাটাবেস রিবিল্ড" \
      "$LSREGISTER" -kill -r -domain local -domain system -domain user
  fi

  # Font cache: garbled text, missing fonts.
  have atsutil && risky_fix "ফন্ট cache রিসেট (রিস্টার্ট লাগবে)" atsutil databases -remove

  # Frozen Finder / Dock / menu bar are restarted safely; macOS relaunches them.
  if [ -n "$CONSOLE_USER" ]; then
    risky_fix "Finder, Dock ও মেনু বার রিস্টার্ট" killall Finder Dock SystemUIServer
  fi

  # Pending sleep blockers
  local blockers
  blockers=$(pmset -g assertions 2>/dev/null | grep -E 'PreventUserIdleSystemSleep|PreventSystemSleep' |
             grep -oE '"[^"]+"' | sort -u | head -n 5 | tr '\n' ' ')
  [ -n "$blockers" ] && info "যারা Mac-কে ঘুমাতে (sleep) দিচ্ছে না: $blockers"
  ok "সার্ভিস পরীক্ষা শেষ"
}
