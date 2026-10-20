#!/bin/bash
#
# MacDoctor — automatic software/macOS diagnosis and repair for
# MacBook Pro 2017 (works on any Intel Mac running macOS 10.13 – 13).
#
# Usage: sudo ./macdoctor.sh [options]
#   --auto        diagnose + apply safe fixes (default)
#   --diagnose    only check, change nothing
#   --full        also offer riskier fixes (asks before each one)
#   --yes         with --full: answer yes to every question
#   --dry-run     print what would be fixed without doing it
#   --quick       skip slow checks (disk verify, update scan)
#   --only LIST   run only these modules, e.g. --only disk,network
#   --report-dir DIR   where to save the report
#   --help

MD_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$MD_DIR/lib/common.sh"

ALL_MODULES="system disk cleanup performance network startup crashes services security battery updates"
ONLY=""
REPORT_DIR=""
ORIG_ARGS=("$@")

usage() { sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --auto)       MODE=auto ;;
    --diagnose)   MODE=diagnose ;;
    --full)       MODE=full ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --dry-run)    DRY_RUN=1 ;;
    --quick)      QUICK=1 ;;
    --only)       shift; ONLY=$(printf '%s' "$1" | tr ',' ' ') ;;
    --report-dir) shift; REPORT_DIR="$1" ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "অজানা অপশন: $1"; usage; exit 2 ;;
  esac
  shift
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "MacDoctor শুধু macOS-এ চলে।"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "MacDoctor-এর অ্যাডমিন অনুমতি লাগবে — আপনার Mac-এর লগইন পাসওয়ার্ড দিন (টাইপ করার সময় কিছু দেখা যাবে না):"
  exec sudo /bin/bash "$0" "${ORIG_ARGS[@]}"
fi

detect_console_user

# Reports go next to the toolkit when it runs from the USB drive,
# otherwise to the user's Desktop.
if [ -z "$REPORT_DIR" ]; then
  case "$MD_DIR" in
    /Volumes/*) REPORT_DIR="$MD_DIR/reports" ;;
    *)          REPORT_DIR="${USER_HOME:-/tmp}/Desktop/MacDoctor-Reports" ;;
  esac
fi
mkdir -p "$REPORT_DIR" 2>/dev/null || REPORT_DIR="/tmp/MacDoctor-Reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/MacDoctor-$(scutil --get ComputerName 2>/dev/null | tr -cd '[:alnum:]-')-$(date +%Y%m%d-%H%M%S).txt"
: > "$REPORT_FILE"

# Load modules
for f in "$MD_DIR"/modules/*.sh; do
  # shellcheck source=/dev/null
  . "$f"
done

printf '%s\n' "${C_BLD}==============================================="
printf '%s\n' "  MacDoctor v$MD_VERSION — আপনার Mac-এর ডাক্তার"
printf '%s\n' "===============================================${C_RST}"
{
  echo "MacDoctor v$MD_VERSION report"
  echo "Date: $(date)"
  echo "Mode: $MODE  dry-run: $DRY_RUN  quick: $QUICK"
} >> "$REPORT_FILE"
case "$MODE" in
  diagnose) info "মোড: শুধু পরীক্ষা — কিছু বদলানো হবে না" ;;
  auto)     info "মোড: স্বয়ংক্রিয় — পরীক্ষা + নিরাপদ সমাধান (আপনার ফাইল মোছা হবে না)" ;;
  full)     info "মোড: সম্পূর্ণ — ঝুঁকিপূর্ণ সমাধানের আগে জিজ্ঞেস করা হবে" ;;
esac
[ "$DRY_RUN" = "1" ] && info "dry-run: শুধু দেখানো হবে কী করা হতো"

notify "পরীক্ষা শুরু হয়েছে… শেষ হলে জানানো হবে।"

for m in ${ONLY:-$ALL_MODULES}; do
  if ! type "mod_$m" >/dev/null 2>&1; then
    warn "অজানা মডিউল: $m"
    continue
  fi
  "mod_$m"
done

# ---- summary ----------------------------------------------------------------
section "সারাংশ (Summary)"
{
  echo "Problems found: $ISSUE_COUNT"; printf '%s' "$ISSUE_LIST"
  echo "Fixes applied: $FIX_COUNT";    printf '%s' "$FIX_LIST"
  echo "Things to do by hand:";        printf '%s' "$ADVICE_LIST"
} >> "$REPORT_FILE"

printf '  সমস্যা পাওয়া গেছে: %s%d%s\n' "$C_BLD" "$ISSUE_COUNT" "$C_RST"
printf '  স্বয়ংক্রিয়ভাবে ঠিক করা হয়েছে: %s%d%s\n' "$C_BLD$C_GRN" "$FIX_COUNT" "$C_RST"
[ "$SKIP_COUNT" -gt 0 ] && printf '  বাদ রাখা সমাধান: %d (চালাতে: --full)\n' "$SKIP_COUNT"
if [ -n "$ADVICE_LIST" ]; then
  printf '\n  %sআপনাকে নিজে যা করতে হবে:%s\n%s' "$C_BLD$C_YEL" "$C_RST" "$ADVICE_LIST"
fi
printf '\n  পূর্ণ রিপোর্ট: %s\n' "$REPORT_FILE"
[ -n "$CONSOLE_USER" ] && chown "$CONSOLE_USER" "$REPORT_FILE" 2>/dev/null

if [ "$ISSUE_COUNT" -eq 0 ]; then
  notify "সব ঠিক আছে! কোনো সমস্যা পাওয়া যায়নি।"
else
  notify "$ISSUE_COUNT টি সমস্যা পাওয়া গেছে, $FIX_COUNT টি ঠিক করা হয়েছে। রিপোর্ট দেখুন।"
fi
exit 0
