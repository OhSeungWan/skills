#!/usr/bin/env bash
# 생성 HTML(인터랙티브 그림·퀴즈)이 이식 가능한 자기완결 파일인지 검증한다:
#   - 바이트 크기 <= 200 KiB (Notion 인라인 첨부 한도와 동일)
#   - 외부 http(s) 참조 없음 (완전 자기완결). w3.org 네임스페이스는 허용.
# 사용법: check-self-contained.sh <file.html>
# 종료코드: 0=통과, 1=검증실패, 2=사용법오류
set -u

MAX_BYTES=204800  # 200 * 1024

if [ "$#" -ne 1 ]; then
  echo "usage: check-self-contained.sh <file.html>" >&2
  exit 2
fi
file="$1"
if [ ! -f "$file" ]; then
  echo "error: file not found: $file" >&2
  exit 2
fi

fail=0

bytes=$(wc -c < "$file" | tr -d ' ')
if [ "$bytes" -gt "$MAX_BYTES" ]; then
  echo "FAIL: $file is ${bytes} bytes (> ${MAX_BYTES} = 200 KiB Notion limit)"
  fail=1
fi

# 외부 참조 검사 — URL 토큰 단위로 추출, 대소문자 무시. w3.org(XML/SVG 네임스페이스)는 허용.
#   1) http(s):// 참조
#   2) ws(s):// 소켓
#   3) 프로토콜상대 참조(//host) — 단, 속성/ url()/ @import 문맥에서만 잡아
#      JS 라인주석(//)을 오탐하지 않는다(구분자 뒤 점 있는 호스트만).
http_off=$(grep -oiE 'https?://[^"'"'"'[:space:]>)]*' "$file" \
  | grep -viE '^https?://(www\.)?w3\.org(/|$)' || true)
ws_off=$(grep -oiE 'wss?://[^"'"'"'[:space:]>)]*' "$file" || true)
proto_off=$(grep -oiE '[=("'"'"']//[a-z0-9._-]+\.[a-z][^"'"'"'[:space:]>)]*' "$file" || true)
offenders=$(printf '%s\n%s\n%s\n' "$http_off" "$ws_off" "$proto_off" | grep -v '^$' || true)
if [ -n "$offenders" ]; then
  echo "FAIL: $file contains external reference(s):"
  echo "$offenders"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: $file (${bytes} bytes, self-contained)"
fi
exit "$fail"
