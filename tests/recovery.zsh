#!/bin/zsh
set -eu

project_dir=${0:A:h:h}
test_dir=$(/usr/bin/mktemp -d)
trap '/bin/rm -rf "$test_dir"' EXIT
export LIDAWAKE_TEST_DIR=$test_dir

/bin/cat > "$test_dir/launchctl" <<'SH'
#!/bin/sh
if [ -e "$LIDAWAKE_TEST_DIR/missing_job" ]; then
  exit 1
fi
/bin/cat "$LIDAWAKE_TEST_DIR/job_state"
SH
/bin/cat > "$test_dir/ioreg" <<'SH'
#!/bin/sh
if [ "$(/bin/cat "$LIDAWAKE_TEST_DIR/power_state")" = disabled ]; then
  printf '"SleepDisabled" = Yes\n'
else
  printf '"SleepDisabled" = No\n'
fi
SH
/bin/cat > "$test_dir/pmset" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$LIDAWAKE_TEST_DIR/pmset_calls"
if [ -e "$LIDAWAKE_TEST_DIR/fail_pmset" ]; then
  exit 1
fi
printf 'allowed\n' > "$LIDAWAKE_TEST_DIR/power_state"
SH
/bin/chmod +x "$test_dir/launchctl" "$test_dir/ioreg" "$test_dir/pmset"

source <(/usr/bin/sed '/^case ${1:-run} in/,$d' "$project_dir/service/recover")
SERVICE_MARKER="$test_dir/active"
LAUNCHCTL="$test_dir/launchctl"
IOREG="$test_dir/ioreg"
PMSET="$test_dir/pmset"

recover_service
if [[ -e "$test_dir/pmset_calls" ]]; then
  print -u2 'Recovery changed sleep without an active session marker.'
  exit 1
fi

print 'state = waiting' > "$test_dir/job_state"
print disabled > "$test_dir/power_state"
/usr/bin/touch "$SERVICE_MARKER"
recover_service
if [[ -e $SERVICE_MARKER || $(/bin/cat "$test_dir/power_state") != allowed ||
      $(/bin/cat "$test_dir/pmset_calls") != '-a disablesleep 0' ]]; then
  print -u2 'Orphaned service did not restore sleep and remove its marker.'
  exit 1
fi

/usr/bin/touch "$test_dir/missing_job" "$SERVICE_MARKER"
print disabled > "$test_dir/power_state"
: > "$test_dir/pmset_calls"
recover_service
if [[ -e $SERVICE_MARKER || $(/bin/cat "$test_dir/power_state") != allowed ]]; then
  print -u2 'Missing service job did not restore sleep.'
  exit 1
fi
/bin/rm -f "$test_dir/missing_job"

print 'state = running' > "$test_dir/job_state"
print disabled > "$test_dir/power_state"
: > "$test_dir/pmset_calls"
/usr/bin/touch "$SERVICE_MARKER"
recover_service
if [[ ! -e $SERVICE_MARKER || $(/bin/cat "$test_dir/power_state") != disabled || -s "$test_dir/pmset_calls" ]]; then
  print -u2 'Recovery changed sleep while the service was running.'
  exit 1
fi

print 'state = waiting' > "$test_dir/job_state"
/usr/bin/touch "$test_dir/fail_pmset"
if recover_service; then
  print -u2 'Failed sleep restoration unexpectedly succeeded.'
  exit 1
fi
if [[ ! -e $SERVICE_MARKER ]]; then
  print -u2 'Failed sleep restoration lost its retry marker.'
  exit 1
fi
/bin/rm -f "$test_dir/fail_pmset"

print allowed > "$test_dir/power_state"
: > "$test_dir/pmset_calls"
recover_service
if [[ -e $SERVICE_MARKER || -s "$test_dir/pmset_calls" ]]; then
  print -u2 'Already restored sleep was changed again.'
  exit 1
fi

print 'Recovery checks passed'
