#!/bin/bash
# shellcheck shell=bash
# Remove regenerable junk: old caches, old logs, Xcode build data.
# Never touches Documents, Desktop, Downloads, Photos or the Trash.

_clean_old() { # $1 = dir, $2 = age in days
  [ -d "$1" ] || return 0
  find "$1" -xdev -type f -mtime +"$2" -delete 2>/dev/null
  find "$1" -xdev -mindepth 1 -type d -empty -delete 2>/dev/null
  return 0
}

_size_of() { du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'; }

mod_cleanup() {
  section "৩. অপ্রয়োজনীয় ফাইল পরিষ্কার (Cleanup)"

  local before after
  before=$(free_bytes)

  if [ -n "$USER_HOME" ] && [ -d "$USER_HOME" ]; then
    info "ইউজার cache: $(human "$(_size_of "$USER_HOME/Library/Caches")")"
    safe_fix "৭ দিনের পুরনো ইউজার cache মোছা" _clean_old "$USER_HOME/Library/Caches" 7
    safe_fix "৩০ দিনের পুরনো ইউজার লগ মোছা" _clean_old "$USER_HOME/Library/Logs" 30

    local dd="$USER_HOME/Library/Developer/Xcode/DerivedData"
    if [ -d "$dd" ]; then
      info "Xcode DerivedData: $(human "$(_size_of "$dd")")"
      safe_fix "Xcode DerivedData মোছা (Xcode আবার তৈরি করে নেবে)" _clean_old "$dd" 0
    fi

    local trash
    trash=$(_size_of "$USER_HOME/.Trash")
    if [ -n "$trash" ] && [ "$trash" -gt 1073741824 ]; then
      advise "Trash-এ $(human "$trash") আছে — দরকার না থাকলে Trash খালি করুন (MacDoctor নিজে আপনার ফাইল মুছবে না)।"
    fi
  else
    warn "লগ-ইন করা ইউজার পাওয়া যায়নি — ইউজার cache বাদ"
  fi

  safe_fix "৩০ দিনের পুরনো সিস্টেম লগ মোছা" _clean_old /Library/Logs 30
  safe_fix "পুরনো সিস্টেম temp ফাইল মোছা" _clean_old /private/var/tmp 7

  after=$(free_bytes)
  if [ "$DRY_RUN" != "1" ] && [ -n "$before" ] && [ -n "$after" ] && [ "$after" -gt "$before" ]; then
    ok "মোট খালি হয়েছে: $(human $((after - before)))"
  fi
}
