#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

plutil -lint service/local.lidawake.plist
if [ "$(plutil -extract RunAtLoad raw service/local.lidawake.plist)" != false ]; then
  printf 'Service must not start at boot\n' >&2
  exit 1
fi
if grep -q '<key>KeepAlive</key>' service/local.lidawake.plist; then
  printf 'Service must not restart after battery cutoff\n' >&2
  exit 1
fi

if output=$(./lidawake service unknown 2>&1); then
  printf 'Unknown service action unexpectedly succeeded\n' >&2
  exit 1
fi
case "$output" in
  *'Usage: lidawake service start | stop | status'*) ;;
  *) printf 'Unexpected service usage output: %s\n' "$output" >&2; exit 1 ;;
esac

output=$(./lidawake service status)
case "$output" in
  *'Service: '*'System sleep: '*) ;;
  *) printf 'Unexpected service status output: %s\n' "$output" >&2; exit 1 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  for action in start stop; do
    if output=$(./lidawake service "$action" 2>&1); then
      printf 'Service %s unexpectedly succeeded without sudo\n' "$action" >&2
      exit 1
    fi
    case "$output" in
      *'Run this command with sudo.'*) ;;
      *) printf 'Unexpected service %s output: %s\n' "$action" "$output" >&2; exit 1 ;;
    esac
  done
fi

printf 'Service checks passed\n'
