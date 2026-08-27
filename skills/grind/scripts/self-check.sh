#!/usr/bin/env bash
# run-tickets.sh 에서 CI 가 절대 실행하지 않는 두 조각을 검사한다.
# 둘 다 jq 식이고 하나는 프롬프트 문자열 안에, 하나는 파이프라인 안에 산다.
# 식은 여기 복붙하지 않고 본체에서 뽑는다 — 사본을 검사하면 본체를 고쳤을 때 낡은 식이 통과한다.
set -euo pipefail

RUNNER="$(cd "$(dirname "$0")" && pwd)/run-tickets.sh"
eval "$(grep '^FILTER=' "$RUNNER")"
eval "$(sed -n "/^RENDER='/,/else empty end'/p" "$RUNNER")"
[ -n "${FILTER:-}" ] && [ -n "${RENDER:-}" ] || { echo "FAIL: run-tickets.sh 에서 FILTER/RENDER 를 못 뽑았다" >&2; exit 1; }

got=$(jq -r "$FILTER | .id" <<'JSON' | paste -sd, -
[
 {"id":1,"reactions":{"+1":0,"eyes":0}},
 {"id":2,"reactions":{"+1":1,"eyes":0}},
 {"id":3,"reactions":{"+1":0,"eyes":1}},
 {"id":4,"reactions":{"+1":0,"eyes":0,"heart":1}},
 {"id":5}
]
JSON
)

# 1 미소진 · 2 반영(+1) · 3 후속(eyes) · 4 무관한 리액션만 · 5 reactions 필드 없음
[ "$got" = "1,4,5" ] || { echo "FAIL: 기대 1,4,5 / 실제 $got" >&2; exit 1; }
echo "ok: 미소진 필터 = $got"

# --- 2. 렌더 파이프라인이 비-JSON 줄에서 producer 를 안 끊는가 -------------------
# 실측 사고: MCP 경고가 stream-json 과 같은 stdout 으로 새서 jq 가 죽고,
# EPIPE 가 tee 를 거쳐 claude 까지 올라가 티켓이 통째로 끊겼다 (exit 144).
# RENDER 는 위에서 본체로부터 eval 로 뽑았다.

raw=$(mktemp) rendered=$(mktemp)
trap 'rm -f "$raw" "$rendered"' EXIT

producer() {
  echo '{"type":"assistant","message":{"content":[{"type":"text","text":"## 구현중"}]}}'
  echo 'Client.listTools() called but server does not advertise tools capability - returning empty list'
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit"}]}}'
  echo '{"type":"result","subtype":"success","num_turns":7}'
  echo "PRODUCER_REACHED_END"   # 여기까지 왔으면 EPIPE 로 안 끊긴 것
}

producer | tee "$raw" | { jq -rR --unbuffered "$RENDER" || cat >/dev/null; } >"$rendered" || true

grep -q PRODUCER_REACHED_END "$raw" || { echo "FAIL: producer 가 끝까지 못 갔다 (EPIPE)" >&2; exit 1; }
[ "$(wc -l <"$rendered")" -eq 2 ] || { echo "FAIL: 렌더 2줄 기대 / 실제:"; cat "$rendered"; exit 1; }
grep -q '## 구현중' "$rendered" || { echo "FAIL: 마커 누락" >&2; exit 1; }
grep -q 'result=success turns=7' "$rendered" || { echo "FAIL: result 줄 누락" >&2; exit 1; }
grep -q 'Edit' "$rendered" && { echo "FAIL: 툴 이름이 stdout 에 샜다" >&2; exit 1; }
echo "ok: 렌더 파이프라인 — 비-JSON 줄 무시, producer 생존, 툴 이름 미노출"
