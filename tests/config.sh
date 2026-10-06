#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT HUP INT TERM
cp "$project_dir/lidawake" "$test_dir/lidawake"

default_status=$(/bin/zsh "$project_dir/lidawake" status)
case "$default_status" in
  *'Duration: infinite'*'Battery floor: 10%'*) ;;
  *) printf 'Expected published defaults to be infinite and 10%%: %s\n' "$default_status" >&2; exit 1 ;;
esac

assert_status_contains() {
  expected=$1
  output=$(/bin/zsh "$test_dir/lidawake" status 2>&1)
  case "$output" in
    *"$expected"*) ;;
    *) printf 'Expected status to contain: %s\nActual: %s\n' "$expected" "$output" >&2; exit 1 ;;
  esac
}

assert_status_rejects() {
  expected=$1
  if output=$(/bin/zsh "$test_dir/lidawake" status 2>&1); then
    printf 'Expected invalid config to fail: %s\n' "$output" >&2
    exit 1
  fi
  case "$output" in
    *"$expected"*) ;;
    *) printf 'Expected error to contain: %s\nActual: %s\n' "$expected" "$output" >&2; exit 1 ;;
  esac
}

cat > "$test_dir/lidawake.conf" <<'EOF'
# Session settings
DURATION_MINUTES=45
BATTERY_FLOOR_PERCENT=20
EOF
assert_status_contains 'Duration: 45 minutes'
assert_status_contains 'Battery floor: 20%'

cat > "$test_dir/lidawake.conf" <<'EOF'
DURATION_MINUTES=infinite
BATTERY_FLOOR_PERCENT=10
EOF
assert_status_contains 'Duration: infinite'

cat > "$test_dir/lidawake.conf" <<'EOF'
DURATION_MINUTES=1440
BATTERY_FLOOR_PERCENT=99
EOF
assert_status_contains 'Duration: 1440 minutes'
assert_status_contains 'Battery floor: 99%'

cat > "$test_dir/lidawake.conf" <<'EOF'
DURATION_MINUTES=0
BATTERY_FLOOR_PERCENT=10
EOF
assert_status_rejects 'Duration must be'

cat > "$test_dir/lidawake.conf" <<'EOF'
DURATION_MINUTES=30
BATTERY_FLOOR_PERCENT=100
EOF
assert_status_rejects 'Battery floor must be'

cat > "$test_dir/lidawake.conf" <<'EOF'
DURATION_MINUTES=30
DURATION_MINUTES=40
BATTERY_FLOOR_PERCENT=10
EOF
assert_status_rejects 'Duplicate setting'

cat > "$test_dir/lidawake.conf" <<'EOF'
DURATION_MINUTES=30
BATTERY_FLOOR_PERCENT=10
UNKNOWN=1
EOF
assert_status_rejects 'Unknown setting'

cat > "$test_dir/lidawake.conf" <<'EOF'
DURATION_MINUTES=30
EOF
assert_status_rejects 'Missing setting'

cat > "$test_dir/lidawake.conf" <<EOF
DURATION_MINUTES=\$(touch $test_dir/injected)
BATTERY_FLOOR_PERCENT=10
EOF
assert_status_rejects 'Duration must be'
if [ -e "$test_dir/injected" ]; then
  printf 'Config value was executed as shell code\n' >&2
  exit 1
fi

cat > "$test_dir/lidawake.conf" <<'EOF'
DURATION_MINUTES=30
BATTERY_FLOOR_PERCENT=10
EOF
if [ "$(id -u)" -ne 0 ]; then
  if output=$(/bin/zsh "$test_dir/lidawake" 2>&1); then
    printf 'Expected no-argument run to require sudo\n' >&2
    exit 1
  fi
  case "$output" in
    *'Run this command with sudo.'*) ;;
    *) printf 'Expected no-argument run to reach root check: %s\n' "$output" >&2; exit 1 ;;
  esac
  if output=$(/bin/zsh "$test_dir/lidawake" run infinite 25 2>&1); then
    printf 'Expected infinite run to require sudo\n' >&2
    exit 1
  fi
  case "$output" in
    *'Run this command with sudo.'*) ;;
    *) printf 'Expected infinite run to reach root check: %s\n' "$output" >&2; exit 1 ;;
  esac
fi

if output=$(/bin/zsh "$test_dir/lidawake" run 0 10 2>&1); then
  printf 'Expected invalid duration override to fail\n' >&2
  exit 1
fi
case "$output" in
  *'Duration must be'*) ;;
  *) printf 'Expected duration override error: %s\n' "$output" >&2; exit 1 ;;
esac

printf 'Config checks passed\n'
