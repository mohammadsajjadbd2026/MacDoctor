#!/bin/bash
#
# Copy MacDoctor onto a USB drive.  Existing files on the drive are kept.
#
# Usage:  ./prepare-usb.sh /Volumes/YOUR_USB      (macOS)
#         ./prepare-usb.sh /media/you/YOUR_USB    (Linux / any other computer)
#
# Tip: format the drive as exFAT or APFS (not FAT32) so large backups fit.

SRC=$(cd "$(dirname "$0")" && pwd)
DEST="$1"

if [ -z "$DEST" ] || [ ! -d "$DEST" ]; then
  echo "ব্যবহার: $0 <USB ড্রাইভের পথ>   যেমন:  $0 /Volumes/MyUSB"
  exit 1
fi

if [ "$(cd "$DEST" && pwd)" = "$SRC" ]; then
  echo "এটি ইতিমধ্যে MacDoctor ফোল্ডার — অন্য একটি USB ড্রাইভ দিন।"
  exit 1
fi

echo "→ $DEST-এ MacDoctor কপি হচ্ছে…"
mkdir -p "$DEST/reports" || exit 1
for item in MacDoctor.command macdoctor.sh setup-autorun.sh README.md lib modules recovery tools docs; do
  rm -rf "${DEST:?}/$item"
  cp -R "$SRC/$item" "$DEST/" || { echo "কপি ব্যর্থ: $item"; exit 1; }
done
chmod +x "$DEST/MacDoctor.command" "$DEST/macdoctor.sh" "$DEST/setup-autorun.sh" \
         "$DEST/recovery/recovery-repair.sh" 2>/dev/null

if [ "$(uname -s)" = "Darwin" ]; then
  # Files downloaded from the internet are blocked by Gatekeeper on double-click.
  xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
  case "$DEST" in
    /Volumes/MACDOCTOR) ;;
    /Volumes/*) diskutil rename "$DEST" MACDOCTOR >/dev/null 2>&1 &&
                  echo "→ ড্রাইভের নাম বদলে MACDOCTOR রাখা হলো" ;;
  esac
fi

echo "✔ USB প্রস্তুত!"
echo "  MacBook-এ লাগিয়ে 'MacDoctor.command'-এ ডাবল-ক্লিক করুন।"
echo "  প্রতিবার শুধু লাগালেই চালু হতে চাইলে একবার চালান:  sudo ./setup-autorun.sh"
