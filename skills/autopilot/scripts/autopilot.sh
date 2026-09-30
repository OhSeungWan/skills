#!/usr/bin/env bash
# 세션을 반복 실행해 컨텍스트 한계를 우회한다. 진행 상태는 STATUS.md가 들고 있다.
set -u
cd "$(dirname "$0")"
LOG=.autopilot.log
LOCK=.autopilot.pid
if [ -e "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
  echo "이미 실행 중 (pid $(cat "$LOCK"))"; exit 1
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

while true; do
  state=$(head -1 STATUS.md 2>/dev/null || true)
  case "$state" in
    "STATE: DONE") echo "완료"; break ;;
    "STATE: BLOCKED_ON_HUMAN") echo "사람 작업 필요 — HUMAN_TODO.md 확인. 처리 후 STATUS.md 첫 줄 지우고 재실행."; break ;;
  esac

  echo "=== 세션 시작 $(date) ===" | tee -a "$LOG"
  claude -p "$(cat AUTOPILOT.md)" --dangerously-skip-permissions 2>&1 | tee -a "$LOG"

  # bmad-loop이 돌고 있으면 세션이 폴링 없이 끝나므로 재기동 간격을 둔다
  sleep 300
done
