#!/bin/zsh
set -eu

project_dir=${0:A:h:h}
script_under_test=${1:-$project_dir/lidawake}
test_dir=$(/usr/bin/mktemp -d)
trap '/bin/rm -rf "$test_dir"' EXIT

print '#!/bin/sh' > "$test_dir/ioreg"
print 'printf '\''%s\n'\'' '\''"SleepDisabled" = No'\''' >> "$test_dir/ioreg"
/bin/chmod +x "$test_dir/ioreg"

# Load the functions without invoking the command-line dispatcher.
source <(/usr/bin/sed '/^case ${1:-run} in/,$d' "$script_under_test")
PMSET=/usr/bin/true
IOREG="$test_dir/ioreg"
SERVICE_MARKER="$test_dir/active"
SERVICE_MODE=true
owns_sleep_override=true
/usr/bin/touch "$SERVICE_MARKER"

restore_sleep
if [[ -e $SERVICE_MARKER || $owns_sleep_override != false ]]; then
  print -u2 'Service exit did not remove its marker after restoring sleep.'
  exit 1
fi
print 'Service cleanup check passed'
