#!/bin/bash
# shellcheck shell=bash
# System overview: model, macOS version, uptime.

mod_system() {
  section "১. সিস্টেম তথ্য (System info)"

  local model os_ver os_build cpu ram_gb uptime_days
  model=$(sysctl -n hw.model 2>/dev/null)
  os_ver=$(sw_vers -productVersion 2>/dev/null)
  os_build=$(sw_vers -buildVersion 2>/dev/null)
  cpu=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
  ram_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))

  info "মডেল: $model"
  info "CPU: $cpu"
  info "RAM: ${ram_gb} GB"
  info "macOS: $os_ver ($os_build)"
  info "ইউজার: ${CONSOLE_USER:-unknown}"

  case "$model" in
    MacBookPro14,1|MacBookPro14,2|MacBookPro14,3)
      ok "MacBook Pro 2017 শনাক্ত হয়েছে ($model)" ;;
    *)
      warn "এটি MacBook Pro 2017 নয় ($model) — বেশিরভাগ চেক তবুও কাজ করবে" ;;
  esac

  # MacBook Pro 2017 officially tops out at macOS Ventura (13.x).
  local major="${os_ver%%.*}"
  if [ -n "$major" ] && [ "$major" -lt 13 ] 2>/dev/null; then
    advise "আপনার Mac সর্বোচ্চ macOS Ventura (13) চালাতে পারে; আপনি $os_ver-এ আছেন। ব্যাকআপ নিয়ে App Store থেকে Ventura-তে আপগ্রেড করলে নিরাপত্তা ও স্থিতিশীলতা বাড়বে।"
  fi

  local boot_epoch now
  boot_epoch=$(sysctl -n kern.boottime 2>/dev/null | sed -E 's/^[{] sec = ([0-9]+).*/\1/')
  now=$(date +%s)
  case "$boot_epoch" in *[!0-9]*) boot_epoch="" ;; esac
  if [ -n "$boot_epoch" ]; then
    uptime_days=$(( (now - boot_epoch) / 86400 ))
    info "শেষ রিস্টার্টের পর: $uptime_days দিন"
    if [ "$uptime_days" -ge 14 ]; then
      issue "Mac $uptime_days দিন ধরে রিস্টার্ট হয়নি — ধীরগতি/অদ্ভুত আচরণের সাধারণ কারণ"
      advise "কাজ সেভ করে Mac একবার রিস্টার্ট করুন।"
    fi
  fi
}
