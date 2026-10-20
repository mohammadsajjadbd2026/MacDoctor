#!/bin/bash
# shellcheck shell=bash
# Launch agents/daemons: broken entries and known adware.

# Name fragments of well-known Mac adware / unwanted software.
ADWARE_PATTERNS="mackeeper|genieo|vsearch|crossrider|conduit|spigot|installmac|pcv\.|mughthesec|advancedmaccleaner|searchmine|bundlore|shlayer|pirrit|macsearch|chumsearch|operator\.helper|zipcloud|macupdater|safefinder"

_plist_program() { # first executable path of a launchd plist
  local p
  p=$(/usr/libexec/PlistBuddy -c "Print :Program" "$1" 2>/dev/null) ||
    p=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$1" 2>/dev/null)
  printf '%s' "$p"
}

_quarantine_plist() { # move a launchd plist out of the way (reversible)
  local plist="$1"
  local q="/Library/Application Support/MacDoctor/quarantine"
  mkdir -p "$q" || return 1
  launchctl unload "$plist" >/dev/null 2>&1
  mv "$plist" "$q/" && echo "সরানো হয়েছে: $q/$(basename "$plist") (ফেরত আনতে আগের জায়গায় কপি করুন)"
}

mod_startup() {
  section "৬. স্টার্টআপ আইটেম ও অ্যাডওয়্যার (Startup items)"

  local dirs="/Library/LaunchAgents /Library/LaunchDaemons"
  [ -n "$USER_HOME" ] && dirs="$USER_HOME/Library/LaunchAgents $dirs"

  local d plist prog label total=0
  for d in $dirs; do
    [ -d "$d" ] || continue
    for plist in "$d"/*.plist; do
      [ -f "$plist" ] || continue
      total=$((total + 1))
      label=$(basename "$plist" .plist)
      prog=$(_plist_program "$plist")
      detail "$plist → $prog"

      if printf '%s %s' "$label" "$prog" | grep -qiE "$ADWARE_PATTERNS"; then
        issue "সন্দেহজনক/অ্যাডওয়্যার স্টার্টআপ আইটেম: $label"
        risky_fix "'$label' স্টার্টআপ থেকে সরিয়ে কোয়ারেন্টাইনে রাখা" _quarantine_plist "$plist"
      elif [ -n "$prog" ] && [ "${prog#/}" != "$prog" ] && [ ! -e "$prog" ]; then
        issue "ভাঙা স্টার্টআপ আইটেম (অ্যাপ মুছে ফেলা হয়েছে): $label"
        risky_fix "ভাঙা আইটেম '$label' সরানো" _quarantine_plist "$plist"
      fi
    done
  done
  info "মোট থার্ড-পার্টি স্টার্টআপ আইটেম: $total"
  [ "$total" -gt 25 ] && advise "অনেক স্টার্টআপ আইটেম — System Settings → General → Login Items-এ অপ্রয়োজনীয়গুলো বন্ধ করুন।"

  # Adware-ish apps in /Applications
  local app
  for app in /Applications/*.app; do
    [ -d "$app" ] || continue
    if basename "$app" | grep -qiE "$ADWARE_PATTERNS"; then
      issue "অপ্রয়োজনীয়/ক্ষতিকর অ্যাপ পাওয়া গেছে: $(basename "$app")"
      advise "'$(basename "$app")' অ্যাপটি Trash-এ ফেলে দিন (নিজের ইনস্টল করা হলে রাখতে পারেন)।"
    fi
  done

  if have kextstat; then
    local kexts
    kexts=$(kextstat -l 2>/dev/null | awk 'NR > 1 {print $6}' | grep -v '^com\.apple' | grep -v '^$')
    if [ -n "$kexts" ]; then
      info "থার্ড-পার্টি kernel extension: $(printf '%s' "$kexts" | tr '\n' ' ')"
      detail "$kexts"
    fi
  fi
  ok "স্টার্টআপ পরীক্ষা শেষ"
}
