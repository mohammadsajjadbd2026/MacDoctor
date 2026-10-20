#!/bin/bash
# shellcheck shell=bash
#
# MacDoctor - shared helpers (logging, fixes, user context).
# macOS ships bash 3.2, so everything here must stay bash 3.2 compatible:
# no associative arrays, no mapfile, no ${var,,}.

# shellcheck disable=SC2034  # used by macdoctor.sh
MD_VERSION="1.0.0"

# ---- run-time settings (overridden by macdoctor.sh flags) -------------------
MODE="${MODE:-auto}"          # diagnose | auto | full
DRY_RUN="${DRY_RUN:-0}"       # 1 = only print what would be done
ASSUME_YES="${ASSUME_YES:-0}" # 1 = answer "yes" to every risky fix (full mode)
QUICK="${QUICK:-0}"           # 1 = skip slow checks (disk verify, update scan)
REPORT_FILE="${REPORT_FILE:-/dev/null}"

ISSUE_COUNT=0
FIX_COUNT=0
SKIP_COUNT=0
ISSUE_LIST=""
FIX_LIST=""
ADVICE_LIST=""

# ---- colours (disabled when not on a terminal) ------------------------------
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m'; C_BLD=$'\033[1m';  C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_BLD=""; C_RST=""
fi

# ---- logging ----------------------------------------------------------------
_log() { # $1 = coloured prefix, $2 = plain prefix, rest = message
  local cpre="$1" ppre="$2"; shift 2
  printf '%s %s\n' "$cpre" "$*"
  printf '%s %s\n' "$ppre" "$*" >> "$REPORT_FILE"
}

section() {
  printf '\n%s== %s ==%s\n' "$C_BLD$C_BLU" "$*" "$C_RST"
  printf '\n== %s ==\n' "$*" >> "$REPORT_FILE"
}
info() { _log "  ${C_BLU}i${C_RST}" "  i" "$@"; }
ok()   { _log "  ${C_GRN}✔${C_RST}" "  OK" "$@"; }
warn() { _log "  ${C_YEL}!${C_RST}" "  WARN" "$@"; }
err()  { _log "  ${C_RED}✖${C_RST}" "  ERROR" "$@"; }

# Raw command output goes to the report only (keeps the screen readable).
detail() { printf '%s\n' "$*" | sed 's/^/      /' >> "$REPORT_FILE"; }

# Record a problem.  $1 = short description.
issue() {
  ISSUE_COUNT=$((ISSUE_COUNT + 1))
  ISSUE_LIST="${ISSUE_LIST}  - $1"$'\n'
  warn "$1"
}

# Record advice the user has to act on by hand (key combos, hardware, ...).
advise() {
  ADVICE_LIST="${ADVICE_LIST}  - $1"$'\n'
  info "পরামর্শ: $1"
}

# ---- fixes ------------------------------------------------------------------
# safe_fix "description" command [args...]
#   Runs in auto and full mode. Never touches personal files.
safe_fix() {
  local desc="$1"; shift
  if [ "$MODE" = "diagnose" ]; then
    info "(ঠিক করা হয়নি, শুধু diagnose মোড) $desc"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return 0
  fi
  _apply_fix "$desc" "$@"
}

# risky_fix "description" command [args...]
#   Runs only in full mode, after confirmation (or --yes).
risky_fix() {
  local desc="$1"; shift
  if [ "$MODE" != "full" ]; then
    info "(বাদ দেওয়া হলো – শুধু --full মোডে চলবে) $desc"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return 0
  fi
  if ! confirm "$desc — করব?"; then
    info "ব্যবহারকারী বাদ দিয়েছেন: $desc"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return 0
  fi
  _apply_fix "$desc" "$@"
}

_apply_fix() {
  local desc="$1"; shift
  if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] $desc  →  $*"
    return 0
  fi
  local out
  if out=$("$@" 2>&1); then
    FIX_COUNT=$((FIX_COUNT + 1))
    FIX_LIST="${FIX_LIST}  - $desc"$'\n'
    ok "ঠিক করা হয়েছে: $desc"
    [ -n "$out" ] && detail "$out"
    return 0
  fi
  err "ব্যর্থ: $desc"
  detail "$out"
  return 1
}

confirm() {
  [ "$ASSUME_YES" = "1" ] && return 0
  # No terminal (autorun) → never do risky things.
  [ -t 0 ] || return 1
  local ans
  printf '  %s?%s %s [y/N] ' "$C_YEL" "$C_RST" "$1"
  read -r ans
  case "$ans" in y|Y|yes|YES|হ্যাঁ) return 0 ;; *) return 1 ;; esac
}

# ---- helpers ----------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# The person sitting at the Mac (we run as root via sudo/launchd).
detect_console_user() {
  CONSOLE_USER=$(stat -f%Su /dev/console 2>/dev/null)
  if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ] || [ "$CONSOLE_USER" = "loginwindow" ]; then
    CONSOLE_USER="${SUDO_USER:-}"
  fi
  USER_HOME=""
  if [ -n "$CONSOLE_USER" ]; then
    USER_HOME=$(dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    [ -z "$USER_HOME" ] && USER_HOME="/Users/$CONSOLE_USER"
  fi
  CONSOLE_UID=$(id -u "$CONSOLE_USER" 2>/dev/null || echo "")
}

# Run a command as the logged-in user, inside their GUI session.
as_user() {
  [ -n "$CONSOLE_USER" ] && [ -n "$CONSOLE_UID" ] || return 1
  launchctl asuser "$CONSOLE_UID" sudo -u "$CONSOLE_USER" "$@"
}

notify() { # $1 = message
  as_user osascript -e "display notification \"$1\" with title \"MacDoctor\"" >/dev/null 2>&1 || true
}

# Free bytes on the boot volume.
free_bytes() { df -k / | awk 'NR==2 {print $4 * 1024}'; }

human() { # bytes → human readable
  awk -v b="${1:-0}" 'BEGIN {
    split("B KB MB GB TB", u, " "); i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf (i == 1 ? "%d %s" : "%.1f %s"), b, u[i] }'
}

# Run with a time limit (macOS has no `timeout`).  $1 = seconds.
with_timeout() {
  local secs="$1"; shift
  "$@" &
  local pid=$!
  # The watcher must not hold stdout open, or $(with_timeout ...) would block.
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  return $rc
}
