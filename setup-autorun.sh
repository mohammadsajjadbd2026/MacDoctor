#!/bin/bash
#
# One-time setup for "plug in the cable and it runs by itself".
#
# macOS never runs programs from a USB drive automatically (security), so this
# installs a small trusted helper on the Mac.  Afterwards, whenever THIS USB
# drive is plugged in, MacDoctor runs in auto mode, saves the report on the
# drive and shows a notification.
#
# Only a drive carrying the secret token created here can trigger it, and the
# code that runs is the copy installed on the Mac, not the code on the drive.
#
# Usage (run from the USB drive, on the Mac):
#   sudo ./setup-autorun.sh             install / update
#   sudo ./setup-autorun.sh --uninstall remove everything

SRC=$(cd "$(dirname "$0")" && pwd)
SUPPORT="/Library/Application Support/MacDoctor"
PLIST=/Library/LaunchDaemons/com.macdoctor.autorun.plist
LABEL=com.macdoctor.autorun

[ "$(uname -s)" = "Darwin" ] || { echo "শুধু macOS-এ চলে।"; exit 1; }
if [ "$(id -u)" -ne 0 ]; then
  echo "অ্যাডমিন পাসওয়ার্ড দিন:"
  exec sudo /bin/bash "$0" "$@"
fi

if [ "$1" = "--uninstall" ]; then
  launchctl bootout system "$PLIST" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null
  rm -f "$PLIST"
  rm -rf "$SUPPORT/app" "$SUPPORT/token" "$SUPPORT/autorun-trigger.sh" "$SUPPORT/run.lock"
  echo "✔ অটো-রান সরিয়ে ফেলা হয়েছে। (কোয়ারেন্টাইন করা ফাইল থাকলে $SUPPORT-এ রয়ে গেছে)"
  exit 0
fi

case "$SRC" in
  /Volumes/*) USB="/Volumes/$(printf '%s' "${SRC#/Volumes/}" | cut -d/ -f1)" ;;
  *) echo "এই স্ক্রিপ্টটি USB ড্রাইভ থেকে চালান (prepare-usb.sh দিয়ে তৈরি)।"; exit 1 ;;
esac

echo "→ MacDoctor এই Mac-এ ইনস্টল হচ্ছে: $SUPPORT"
mkdir -p "$SUPPORT/app"
rm -rf "$SUPPORT/app/lib" "$SUPPORT/app/modules"
cp -R "$SRC/macdoctor.sh" "$SRC/lib" "$SRC/modules" "$SUPPORT/app/"
cp "$SRC/tools/autorun-trigger.sh" "$SUPPORT/autorun-trigger.sh"
chown -R root:wheel "$SUPPORT"
chmod -R go-w "$SUPPORT"
xattr -dr com.apple.quarantine "$SUPPORT" 2>/dev/null

# Pair this drive with this Mac.
if [ ! -s "$SUPPORT/token" ]; then
  ( umask 077; openssl rand -hex 32 > "$SUPPORT/token" )
fi
cp "$SUPPORT/token" "$USB/.macdoctor-token"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SUPPORT/autorun-trigger.sh</string>
  </array>
  <key>StartOnMount</key><true/>
  <key>StandardOutPath</key><string>/var/log/macdoctor-autorun.log</string>
  <key>StandardErrorPath</key><string>/var/log/macdoctor-autorun.log</string>
</dict>
</plist>
EOF
chown root:wheel "$PLIST"
chmod 644 "$PLIST"
launchctl bootout system "$PLIST" 2>/dev/null
launchctl bootstrap system "$PLIST" 2>/dev/null || launchctl load -w "$PLIST"

echo
echo "✔ সেটআপ সম্পূর্ণ!"
echo "  এখন থেকে এই USB ড্রাইভ ($USB) লাগালেই MacDoctor নিজে চলবে,"
echo "  রিপোর্ট ড্রাইভের 'reports' ফোল্ডারে জমা হবে এবং শেষে নোটিফিকেশন আসবে।"
echo
echo "  নোট: প্রথমবার না চললে System Settings → Privacy & Security →"
echo "  Full Disk Access-এ '+' চেপে /bin/bash যোগ করুন (⌘⇧G চেপে /bin/bash লিখুন)।"
echo "  সরাতে চাইলে:  sudo ./setup-autorun.sh --uninstall"
