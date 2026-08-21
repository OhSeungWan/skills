#!/usr/bin/env bash
# 미소진 코멘트 필터의 유일한 자동 검사. run-tickets.sh 의 $UNREAD 와 같은 jq 식을 쓴다.
# 이 식은 프롬프트 문자열 안에 살아서 CI 가 절대 실행하지 않으므로, 여기서라도 한 번 돈다.
set -euo pipefail

FILTER='.[] | select((.reactions["+1"] // 0) == 0 and (.reactions.eyes // 0) == 0) | .id'

got=$(jq -r "$FILTER" <<'JSON' | paste -sd, -
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
