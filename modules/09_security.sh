#!/bin/bash
# shellcheck shell=bash
# SIP, Gatekeeper, firewall, FileVault.

mod_security() {
  section "৯. নিরাপত্তা (Security)"

  case "$(csrutil status 2>/dev/null)" in
    *enabled*)  ok "System Integrity Protection চালু" ;;
    *disabled*) issue "System Integrity Protection (SIP) বন্ধ — ম্যালওয়্যারের ঝুঁকি"
                advise "Recovery Mode (⌘+R) → Terminal → 'csrutil enable' → রিস্টার্ট।" ;;
  esac

  case "$(spctl --status 2>/dev/null)" in
    *enabled*)  ok "Gatekeeper চালু" ;;
    *disabled*) issue "Gatekeeper বন্ধ — যেকোনো অচেনা অ্যাপ চলতে পারে"
                risky_fix "Gatekeeper চালু করা" spctl --master-enable ;;
  esac

  local fw=/usr/libexec/ApplicationFirewall/socketfilterfw
  if [ -x "$fw" ]; then
    case "$("$fw" --getglobalstate 2>/dev/null)" in
      *enabled*) ok "ফায়ারওয়াল চালু" ;;
      *)         issue "ফায়ারওয়াল বন্ধ"
                 risky_fix "ফায়ারওয়াল চালু করা" "$fw" --setglobalstate on ;;
    esac
  fi

  case "$(fdesetup status 2>/dev/null)" in
    *"is On"*)  ok "FileVault ডিস্ক এনক্রিপশন চালু" ;;
    *"is Off"*) advise "FileVault বন্ধ — ল্যাপটপ চুরি হলে ফাইল পড়া যাবে। System Settings → Privacy & Security → FileVault।" ;;
  esac

  local xp
  xp=$(defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>/dev/null)
  [ -n "$xp" ] && info "XProtect (Apple-এর বিল্ট-ইন অ্যান্টিভাইরাস) ভার্সন: $xp"
}
