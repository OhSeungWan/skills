#!/usr/bin/env bash
# check-self-contained.sh 의 동작을 픽스처로 검증한다.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$DIR/../scripts/check-self-contained.sh"
FIX="$DIR/fixtures"
fail=0

expect_exit() { # <expected_code> <label> <args...>
  local exp="$1" label="$2"; shift 2
  "$SCRIPT" "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$exp" ]; then echo "PASS: $label"; else echo "FAIL: $label (expected $exp, got $got)"; fail=1; fi
}

expect_exit 0 "clean.html passes"    "$FIX/clean.html"
expect_exit 0 "svg-ok.html passes"   "$FIX/svg-ok.html"
expect_exit 1 "external.html fails"  "$FIX/external.html"
expect_exit 1 "mixed-line w3.org + external fails" "$FIX/mixed-line.html"
expect_exit 1 "uppercase scheme fails"             "$FIX/uppercase-scheme.html"
expect_exit 1 "protocol-relative src fails"        "$FIX/protocol-relative.html"
expect_exit 1 "websocket wss:// fails"             "$FIX/websocket.html"
expect_exit 1 "protocol-relative url() fails"      "$FIX/css-url-protorel.html"
expect_exit 0 "js // comment does not false-fail"  "$FIX/js-comment-ok.html"
expect_exit 2 "missing file usage"   "$FIX/does-not-exist.html"
expect_exit 2 "no args usage"

exit $fail
