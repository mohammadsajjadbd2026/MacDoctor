#!/bin/bash
#
# Runs MacDoctor on a non-Mac (Linux CI) with stubbed macOS commands, to catch
# script errors.  Usage: tests/mock-run.sh [macdoctor options]
# Scenario knobs (env): MOCK_LOWDISK=1, MOCK_OFFLINE=1, MOCK_PANIC=1

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
HOME_DIR="$WORK/home/tester"
mkdir -p "$BIN" "$HOME_DIR/Library/Caches/old" "$HOME_DIR/Library/Logs"
echo junk > "$HOME_DIR/Library/Caches/old/file"
touch -d '30 days ago' "$HOME_DIR/Library/Caches/old/file"

stub() { printf '#!/bin/bash\n%s\n' "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }

stub uname        'echo Darwin'
stub id           '[ "$1" = "-u" ] && { [ -n "${2:-}" ] && echo 501 || echo 0; } || /usr/bin/id "$@"'
stub sudo         'while [ "${1#-}" != "$1" ]; do shift; [ "$1" ] && shift; done; "$@"'
stub stat         'if [ "$1" = "-f%Su" ]; then echo tester; else /usr/bin/stat "$@"; fi'
stub dscl         "echo 'NFSHomeDirectory: $HOME_DIR'"
stub launchctl    'shift 2; "$@"'
stub osascript    'exit 0'
stub scutil       'echo Test-MacBook'
stub sysctl       'case "$2" in
  hw.model) echo MacBookPro14,3 ;;
  machdep.cpu.brand_string) echo "Intel(R) Core(TM) i7-7820HQ CPU @ 2.90GHz" ;;
  hw.memsize) echo 17179869184 ;;
  kern.boottime) echo "{ sec = $(( $(date +%s) - 20*86400 )), usec = 0 }" ;;
  vm.swapusage) echo "total = 6144.00M  used = 5120.50M  free = 1023.50M" ;;
esac'
stub sw_vers      '[ "$1" = "-productVersion" ] && echo 12.7.6 || echo 21H1320'
stub diskutil     'case "$1" in
  info) echo "   SMART Status:              Verified" ;;
  verifyVolume) echo "The volume was verified successfully" ;;
esac'
if [ "${MOCK_LOWDISK:-0}" = 1 ]; then
  stub df 'echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "/dev/disk1s1 976490576 966490576 10000000 99% /"'
fi
stub tmutil       'echo "Thinned local snapshots"'
stub memory_pressure 'echo "System-wide memory free percentage: 9%"'
stub purge        'exit 0'
stub ps           'printf "  101 95.0 Google Chrome Helper\n  0 12.0 kernel_task\n  300 1.0 Finder\n"'
stub networksetup 'case "$1" in -listallhardwareports) printf "Hardware Port: Wi-Fi\nDevice: en0\n" ;; esac'
stub route        'echo "    gateway: 192.168.1.1"'
if [ "${MOCK_OFFLINE:-0}" = 1 ]; then stub ping 'exit 2'; else stub ping 'exit 0'; fi
stub dscacheutil  'echo "ip_address: 17.253.144.10"'
stub killall      'exit 0'
stub ipconfig     'exit 0'
stub kextstat     'printf "Index Refs Address Size Wired Name\n 1 0 0 0 0 com.apple.kpi\n 2 0 0 0 0 com.vendor.driver (1.0)\n"'
stub systemsetup  'echo "Network Time: Off"'
stub mdutil       'printf "/:\n\tIndexing enabled.\n"'
stub atsutil      'exit 0'
stub pmset        'case "$2" in therm) echo "CPU_Speed_Limit = 70" ;; assertions) echo "pid 101(Chrome): PreventUserIdleSystemSleep named: \"Playing video\"" ;; esac'
stub csrutil      'echo "System Integrity Protection status: enabled."'
stub spctl        'echo "assessments disabled"'
stub fdesetup     'echo "FileVault is Off."'
stub defaults     'echo 2195'
stub system_profiler 'printf "      Cycle Count: 1042\n      Condition: Service Recommended\n"'
stub softwareupdate 'printf "Software Update Tool\n* Label: macOS Monterey 12.7.7-21H1400\n\tTitle: macOS Monterey\n"'

PATH="$BIN:$PATH" bash "$ROOT/macdoctor.sh" --report-dir "$WORK/reports" "$@"
rc=$?
echo "---- report ----"
cat "$WORK"/reports/*.txt
exit $rc
