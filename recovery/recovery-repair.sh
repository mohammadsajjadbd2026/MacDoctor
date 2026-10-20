#!/bin/sh
#
# MacDoctor Recovery — for a Mac that will not start up properly.
#
# 1. Turn the Mac off.  Plug in the MACDOCTOR USB drive.
# 2. Press power and immediately hold ⌘ (Command) + R until the Apple logo
#    appears (no luck? hold ⌥ + ⌘ + R for Internet Recovery).
# 3. Menu bar → Utilities → Terminal, then type:
#        sh /Volumes/MACDOCTOR/recovery/recovery-repair.sh
#
# Plain POSIX sh: the Recovery system has a very small set of tools.

USB=$(cd "$(dirname "$0")/.." && pwd)
LOG="$USB/reports/recovery-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$USB/reports" 2>/dev/null || LOG=/dev/null

say() { printf '%s\n' "$*"; printf '%s\n' "$*" >> "$LOG"; }
run() { say "\$ $*"; "$@" 2>&1 | tee -a "$LOG"; }
ask() { printf '%s [y/N] ' "$1"; read -r a; case "$a" in y|Y|yes) return 0 ;; esac; return 1; }

# Internal APFS container, e.g. disk1
container() {
  diskutil list internal 2>/dev/null | awk '/Apple_APFS/ && /Container/ {
    for (i = 1; i <= NF; i++) if ($i == "Container") { print $(i+1); exit } }'
}

# Volumes inside the container, e.g. disk1s1 disk1s2 ...
volumes() {
  diskutil apfs list "$1" 2>/dev/null | grep 'APFS Volume Disk' | grep -oE 'disk[0-9]+s[0-9]+' | sort -u
}

# Mount point of the "Data" volume (user files), mounting/unlocking it if needed.
data_volume() {
  c=$(container)
  for v in $(volumes "$c"); do
    if diskutil apfs list "$c" | grep -E "${v}[[:space:]]+\(Data\)" >/dev/null; then
      mp=$(diskutil info "$v" | awk -F: '/Mount Point/ {sub(/^ +/, "", $2); print $2}')
      if [ -z "$mp" ]; then
        diskutil mount "$v" >/dev/null 2>&1 || {
          say "ডিস্ক লক করা (FileVault)। আপনার Mac-এর লগইন পাসওয়ার্ড দিন:" >&2
          diskutil apfs unlockVolume "$v" >/dev/null
        }
        mp=$(diskutil info "$v" | awk -F: '/Mount Point/ {sub(/^ +/, "", $2); print $2}')
      fi
      [ -n "$mp" ] && { printf '%s' "$mp"; return 0; }
    fi
  done
  return 1
}

first_aid() {
  c=$(container)
  [ -n "$c" ] || { say "অভ্যন্তরীণ APFS ডিস্ক পাওয়া যায়নি।"; run diskutil list; return; }
  say "== First Aid: প্রথমে ভলিউম, তারপর কন্টেইনার (Apple-এর নির্ধারিত ক্রম) =="
  for v in $(volumes "$c"); do run diskutil repairVolume "$v"; done
  run diskutil repairVolume "$c"
  say "শেষ। 'error' বা 'corrupt' দেখালে আরেকবার চালান; বারবার দেখালে ব্যাকআপ নিয়ে macOS রিইনস্টল করুন।"
}

backup_files() {
  data=$(data_volume) || { say "ইউজার ডিস্ক খোলা যায়নি।"; return; }
  users=""
  for d in "$data"/Users/*; do
    [ -d "$d" ] && [ "$(basename "$d")" != Shared ] && users="$users $(basename "$d")"
  done
  say "ইউজার:$users"
  printf 'কোন ইউজারের ফাইল ব্যাকআপ নেব? '; read -r u
  [ -d "$data/Users/$u" ] || { say "এই নামে ইউজার নেই।"; return; }
  dest="$USB/backup/$u-$(date +%Y%m%d-%H%M)"
  need=0
  for d in Desktop Documents Pictures Movies Music Downloads; do
    [ -d "$data/Users/$u/$d" ] && need=$((need + $(du -sk "$data/Users/$u/$d" | awk '{print $1}')))
  done
  have=$(df -k "$USB" | awk 'NR==2 {print $4}')
  say "দরকার: $((need / 1024)) MB   USB-তে ফাঁকা: $((have / 1024)) MB"
  [ "$need" -lt "$have" ] || { say "USB-তে জায়গা নেই — বড় ড্রাইভ লাগবে।"; return; }
  mkdir -p "$dest"
  for d in Desktop Documents Pictures Movies Music Downloads; do
    [ -d "$data/Users/$u/$d" ] && run ditto "$data/Users/$u/$d" "$dest/$d"
  done
  say "✔ ব্যাকআপ রাখা হয়েছে: $dest"
}

reset_nvram() {
  run nvram -c && say "✔ NVRAM রিসেট হয়েছে। এখন Apple মেনু → Restart।"
}

quarantine_startup() {
  data=$(data_volume) || { say "ইউজার ডিস্ক খোলা যায়নি।"; return; }
  say "Mac চালু হতে গিয়ে আটকে গেলে (লোডিং বার/লুপ) প্রায়ই কোনো থার্ড-পার্টি স্টার্টআপ প্রোগ্রাম দায়ী।"
  ask "সব থার্ড-পার্টি LaunchDaemon/LaunchAgent সরিয়ে রাখব? (পরে ফেরত আনা যাবে)" || return
  q="$data/MacDoctor-quarantine-$(date +%Y%m%d%H%M)"
  mkdir -p "$q/LaunchDaemons" "$q/LaunchAgents"
  for f in "$data"/Library/LaunchDaemons/*.plist; do [ -f "$f" ] && mv "$f" "$q/LaunchDaemons/"; done
  for f in "$data"/Library/LaunchAgents/*.plist;  do [ -f "$f" ] && mv "$f" "$q/LaunchAgents/"; done
  say "✔ সরানো হয়েছে: $q"
  say "  Mac ঠিকমতো চালু হলে দরকারি আইটেমগুলো /Library/LaunchDaemons বা LaunchAgents-এ ফেরত কপি করুন।"
}

reinstall_help() {
  say "macOS রিইনস্টল করলে আপনার ফাইল ও অ্যাপ থেকে যায়, শুধু সিস্টেম নতুন হয়:"
  say "  1. এই Terminal বন্ধ করুন (⌘Q)।"
  say "  2. 'Reinstall macOS' বেছে নিন → Continue → 'Macintosh HD' ডিস্ক।"
  say "  3. চার্জার লাগিয়ে রাখুন, ইন্টারনেট লাগবে, ৩০–৬০ মিনিট সময় লাগবে।"
  say "  আগে অপশন 2 দিয়ে ফাইলের ব্যাকআপ নিয়ে রাখা ভালো।"
  say ""
  say "OpenCore Legacy Patcher দিয়ে Sequoia বসানো থাকলে: Internet Recovery (⌥+⌘+R) থেকে"
  say "Apple-এর অফিসিয়াল macOS Ventura বসানোই সবচেয়ে স্থিতিশীল। Sequoia-এর ডিস্কের ওপর"
  say "Ventura বসানো যায় না (পুরনো ভার্সন) — আগে ব্যাকআপ, তারপর Disk Utility-তে Erase করে Ventura।"
}

# Read the newest kernel panics from the internal disk and say what they point to.
panic_reasons() {
  data=$(data_volume) || { say "ইউজার ডিস্ক খোলা যায়নি।"; return; }
  files=$(find "$data/Library/Logs/DiagnosticReports" -maxdepth 2 -type f \
            \( -name '*.panic' -o -name 'panic-*' -o -name 'Kernel*' \) 2>/dev/null)
  if [ -z "$files" ]; then
    say "কোনো kernel panic রিপোর্ট পাওয়া যায়নি (Mac হয়তো macOS লোড হওয়ার আগেই আটকে যাচ্ছে)।"
    return
  fi
  say "মোট panic রিপোর্ট: $(printf '%s\n' "$files" | grep -c .)"
  # newest 3
  newest=$(printf '%s\n' "$files" | while read -r f; do
             printf '%s %s\n' "$(stat -f %m "$f" 2>/dev/null || echo 0)" "$f"; done |
           sort -rn | head -n 3 | cut -d' ' -f2-)
  all=""
  printf '%s\n' "$newest" | while read -r f; do
    [ -n "$f" ] || continue
    say ""
    say "--- $(basename "$f") ---"
    grep -oE 'panic[(]cpu[^"\\]{0,300}' "$f" 2>/dev/null | head -n 1 | tee -a "$LOG"
  done
  all=$(printf '%s\n' "$newest" | while read -r f; do [ -n "$f" ] && head -c 20000 "$f"; done)
  say ""
  say "=== MacDoctor-এর বিশ্লেষণ ==="
  found=0
  if printf '%s' "$all" | grep -qiE 'AMDRadeon|AMD[A-Za-z0-9]*Controller|GPU (Restart|Panic)|IOGPU|AppleGPUWrangler|gfx'; then
    say "• গ্রাফিক্স (GPU) সম্পর্কিত crash — স্ক্রিনের সমস্যার সাথে মিলিয়ে এটি সম্ভবত AMD GPU/লজিক বোর্ডের"
    say "  হার্ডওয়্যার সমস্যা (2016-2017 15\" MacBook Pro-তে গরমে এটা পরিচিত)। অপশন 7 দেখুন।"; found=1
  fi
  if printf '%s' "$all" | grep -qiE 'thermal|overtemp|SMC::smcHandle|ACPI_SMC'; then
    say "• তাপ/SMC সম্পর্কিত — SMC রিসেট করুন, ফ্যান ও ভেন্ট পরিষ্কার করান।"; found=1
  fi
  if printf '%s' "$all" | grep -qiE 'NVMe|IONVMe|AppleANS|apfs_'; then
    say "• SSD/স্টোরেজ সম্পর্কিত — অপশন 1 (First Aid) চালান, এখনই ব্যাকআপ নিন (অপশন 2)।"; found=1
  fi
  if printf '%s' "$all" | grep -qiE 'Lilu|WhateverGreen|RestrictEvents|AMFIPass|CryptexFixup|OpenCore'; then
    say "• OpenCore Legacy Patcher-এর kext crash-এ জড়িত — Sequoia প্যাচ নষ্ট হয়েছে।"
    say "  সমাধান: ব্যাকআপ নিয়ে অফিসিয়াল Ventura বসানো (অপশন 5)।"; found=1
  fi
  [ "$found" = 0 ] && say "• নির্দিষ্ট কারণ ধরা যায়নি — রিপোর্টটি ($LOG) কাউকে দেখান।"
}

# Is this the 15-inch model with an AMD graphics chip?
has_dgpu() {
  case "$(sysctl -n hw.model 2>/dev/null)" in MacBookPro14,3|MacBookPro13,3) return 0 ;; esac
  return 1
}

force_igpu() {
  say "মডেল: $(sysctl -n hw.model 2>/dev/null)"
  if ! has_dgpu; then
    say "এই মডেলে আলাদা AMD গ্রাফিক্স নেই (13\") — এটি প্রযোজ্য নয়।"
    say "স্ক্রিনে দাগ/ঝিলমিল থাকলে সম্ভবত ডিসপ্লে বা ডিসপ্লে-ক্যাবলের হার্ডওয়্যার সমস্যা।"
    return
  fi
  say "15\" MacBook Pro 2017-এ দুটি গ্রাফিক্স চিপ আছে: Intel (ছোট) আর AMD Radeon (গরম হয়, নষ্ট হয় বেশি)।"
  say "AMD চিপ নষ্ট হলে স্ক্রিনে দাগ/কালো স্ক্রিন আর চালু হওয়ার সময় crash হয়।"
  say "এই সেটিং Mac-কে শুধু Intel গ্রাফিক্স দিয়ে চালু করতে বলে। এটা পরীক্ষা মাত্র, স্থায়ী মেরামত নয়;"
  say "বাইরের মনিটর (HDMI/USB-C) এতে কাজ না-ও করতে পারে। ফেরত আনতে: NVRAM রিসেট (অপশন 3)।"
  ask "Intel গ্রাফিক্স দিয়ে চালু করার সেটিং দেব?" || return
  run nvram fa4ce28d-b62f-4c99-9cc3-6815686e30f9:gpu-power-prefs=%01%00%00%00 &&
    say "✔ দেওয়া হয়েছে। Apple মেনু → Restart। ঠিকমতো চালু হলে সমস্যা AMD GPU-তে — সার্ভিস সেন্টারে লজিক বোর্ড দেখান।"
}

boot_status() {
  say "== ডিস্কের পার্টিশন =="
  run diskutil list internal
  if diskutil list internal 2>/dev/null | grep -qiE 'BOOTCAMP|Microsoft Basic Data'; then
    say "• Windows (Boot Camp) পার্টিশন আছে।"
  fi
  efi=$(diskutil list internal 2>/dev/null | awk '/EFI/ {print $NF; exit}')
  if [ -n "$efi" ] && diskutil mount "$efi" >/dev/null 2>&1; then
    mp=$(diskutil info "$efi" | awk -F: '/Mount Point/ {sub(/^ +/, "", $2); print $2}')
    if [ -f "$mp/EFI/OC/OpenCore.efi" ]; then
      say "• OpenCore (OCLP) EFI-তে ইনস্টল আছে: $mp/EFI/OC"
    else
      say "• OpenCore পাওয়া যায়নি — Sequoia চালু করতে OpenCore লাগে, তাই এটা না থাকলে Sequoia বুট হবে না।"
    fi
    diskutil unmount "$efi" >/dev/null 2>&1
  fi
  say "== NVRAM-এর বুট সেটিং =="
  nvram boot-args 2>&1 | tee -a "$LOG"
  nvram csr-active-config 2>&1 | tee -a "$LOG"
  say ""
  say "সহজ পরীক্ষা: Mac চালু করেই ⌥ Option চেপে ধরুন → সরাসরি 'Windows' বা 'EFI Boot' বেছে নিন।"
  say "দুটোই crash করলে সমস্যা প্রায় নিশ্চিত হার্ডওয়্যারে (GPU/গরম), সফটওয়্যারে নয়।"
}

say "MacDoctor Recovery — $(date)"
while :; do
  echo
  echo "=========== MacDoctor Recovery ==========="
  echo " 1) ডিস্ক পরীক্ষা ও মেরামত (First Aid)"
  echo " 2) জরুরি ফাইল USB-তে ব্যাকআপ"
  echo " 3) NVRAM রিসেট"
  echo " 4) চালু হতে আটকে যায় → স্টার্টআপ প্রোগ্রাম সরানো"
  echo " 5) macOS রিইনস্টলের নিয়ম (ফাইল মোছা হয় না)"
  echo " 6) crash-এর কারণ খুঁজে বের করা (kernel panic রিপোর্ট)"
  echo " 7) স্ক্রিন/গ্রাফিক্স সমস্যা → শুধু Intel GPU দিয়ে চালু (15\" মডেল)"
  echo " 8) বুট অবস্থা: Windows, OpenCore (Sequoia patcher), NVRAM"
  echo " 0) বের হও"
  printf 'বেছে নিন [0-8]: '; read -r choice
  case "$choice" in
    1) first_aid ;;
    2) backup_files ;;
    3) reset_nvram ;;
    4) quarantine_startup ;;
    5) reinstall_help ;;
    6) panic_reasons ;;
    7) force_igpu ;;
    8) boot_status ;;
    0) say "লগ: $LOG"; exit 0 ;;
  esac
done
