#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

TMPDIR=""

cleanup() {
  if [[ -n $TMPDIR && -d $TMPDIR ]]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

# Stand in for the user manager: a marker file is the running unit, and every
# call is logged so the test can see what was started.
TMPDIR=$(mktemp -d)
stub_bin="$TMPDIR/bin"
unit="$TMPDIR/unit-active"
log="$TMPDIR/calls"
mkdir -p "$stub_bin"

cat >"$stub_bin/systemctl" <<STUB
#!/bin/bash
echo "systemctl \$*" >>"$log"
case "\$*" in
  *is-active*) [[ -f "$unit" ]] ;;
  *stop*) rm -f "$unit" ;;
esac
STUB

cat >"$stub_bin/systemd-run" <<STUB
#!/bin/bash
echo "systemd-run \$*" >>"$log"
touch "$unit"
STUB

printf '#!/bin/bash\necho "omarchy-shell $*" >>"%s"\n' "$log" >"$stub_bin/omarchy-shell"
chmod +x "$stub_bin"/*
export PATH="$stub_bin:$ROOT/bin:$PATH"

omarchy-toggle-lid-awake status | grep -q '"enabled":false' || fail "lid awake reports off by default"
pass "lid awake reports off by default"

omarchy-toggle-lid-awake on
[[ -f $unit ]] || fail "lid awake on starts the inhibitor unit"
grep -q -- '--what=handle-lid-switch' "$log" || fail "lid awake inhibits only the lid switch"
grep -q -- '--unit=omarchy-lid-awake' "$log" || fail "lid awake runs as the omarchy-lid-awake unit"
pass "lid awake on starts a lid-switch inhibitor"

grep -q 'omarchy-shell omarchy.indicators refresh' "$log" || fail "lid awake refreshes the bar indicator"
pass "lid awake refreshes the bar indicator"

: >"$log"
omarchy-toggle-lid-awake on
! grep -q 'systemd-run' "$log" || fail "lid awake on is idempotent"
pass "lid awake on is idempotent"

omarchy-toggle-lid-awake status | grep -q '"enabled":true' || fail "lid awake reports on"
pass "lid awake reports on"

omarchy-toggle-lid-awake
[[ ! -f $unit ]] || fail "lid awake toggle turns it off"
pass "lid awake toggle turns it off"

omarchy-toggle-lid-awake toggle
[[ -f $unit ]] || fail "lid awake toggle turns it on"
pass "lid awake toggle turns it on"

omarchy-toggle-lid-awake off
omarchy-toggle-lid-awake off
[[ ! -f $unit ]] || fail "lid awake off is idempotent"
pass "lid awake off is idempotent"

if omarchy-toggle-lid-awake bogus 2>/dev/null; then
  fail "lid awake rejects unknown arguments"
fi
pass "lid awake rejects unknown arguments"
