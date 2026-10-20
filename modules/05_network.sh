#!/bin/bash
# shellcheck shell=bash
# Internet / Wi-Fi / DNS.

_wifi_device() {
  networksetup -listallhardwareports 2>/dev/null |
    awk '/Hardware Port: (Wi-Fi|AirPort)/ {getline; print $2; exit}'
}

_online() { ping -c 2 -t 4 1.1.1.1 >/dev/null 2>&1 || ping -c 2 -t 4 8.8.8.8 >/dev/null 2>&1; }
_dns_ok() { dscacheutil -q host -a name apple.com 2>/dev/null | grep -q ip_address; }

_toggle_wifi() {
  networksetup -setairportpower "$1" off && sleep 3 && networksetup -setairportpower "$1" on && sleep 10
}

_reset_network_prefs() {
  local src=/Library/Preferences/SystemConfiguration
  local bak
  bak="/Library/Preferences/SystemConfiguration-MacDoctor-backup-$(date +%Y%m%d%H%M%S)"
  mkdir -p "$bak" || return 1
  local f
  for f in NetworkInterfaces.plist preferences.plist com.apple.airport.preferences.plist; do
    [ -f "$src/$f" ] && mv "$src/$f" "$bak/"
  done
  echo "ব্যাকআপ: $bak  (রিস্টার্টের পর নতুন সেটিং তৈরি হবে)"
}

mod_network() {
  section "৫. ইন্টারনেট ও নেটওয়ার্ক (Network)"

  local wifi gw
  wifi=$(_wifi_device)
  gw=$(route -n get default 2>/dev/null | awk '/gateway/ {print $2}')
  info "Wi-Fi ডিভাইস: ${wifi:-নেই}   রাউটার: ${gw:-নেই}"

  # DNS cache flush is harmless and fixes many "site won't open" problems.
  safe_fix "DNS cache পরিষ্কার" sh -c 'dscacheutil -flushcache; killall -HUP mDNSResponder'

  if _online; then
    ok "ইন্টারনেট সংযোগ আছে"
    if _dns_ok; then
      ok "DNS কাজ করছে"
    else
      issue "ইন্টারনেট আছে কিন্তু ওয়েবসাইটের নাম খুঁজে পাচ্ছে না (DNS সমস্যা)"
      advise "System Settings → Network → Wi-Fi → Details → DNS-এ 1.1.1.1 ও 8.8.8.8 যোগ করে দেখুন।"
    fi
    return 0
  fi

  issue "ইন্টারনেট সংযোগ নেই"
  if [ -z "$wifi" ]; then
    advise "Wi-Fi হার্ডওয়্যার পাওয়া যায়নি — রিস্টার্ট করুন; না সারলে NVRAM রিসেট করুন (docs/KEY_COMBOS.md)।"
    return 0
  fi

  if [ -n "$gw" ] && ! ping -c 2 -t 4 "$gw" >/dev/null 2>&1; then
    warn "রাউটারেও পৌঁছানো যাচ্ছে না"
  fi
  safe_fix "নতুন IP নেওয়া (DHCP renew)" ipconfig set "$wifi" DHCP
  safe_fix "Wi-Fi বন্ধ করে আবার চালু করা" _toggle_wifi "$wifi"

  if [ "$DRY_RUN" != "1" ] && [ "$MODE" != "diagnose" ] && _online; then
    ok "ইন্টারনেট আবার চালু হয়েছে"
    return 0
  fi
  risky_fix "নেটওয়ার্ক সেটিং রিসেট করা (Wi-Fi পাসওয়ার্ড আবার দিতে হবে, রিস্টার্ট লাগবে)" _reset_network_prefs
  advise "রাউটার রিস্টার্ট করুন এবং অন্য ডিভাইসে ইন্টারনেট চলছে কিনা দেখুন।"
}
