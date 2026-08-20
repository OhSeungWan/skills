#!/usr/bin/env bash
#
# 티켓 자동 소진 러너 — 티켓 1장 = orca 워크트리 1개 = claude 프로세스 1개 = 컨텍스트 0에서 시작.
#
# 사용법: 통합 브랜치를 체크아웃한 워크트리에서 실행한다.
#   .git/matt-context/run-tickets.sh 193
#   .git/matt-context/run-tickets.sh 193 194 196 212 213
#
# repo·통합 브랜치·통합 PR 번호는 전부 현재 체크아웃에서 감지한다 — 트랙별 설정이 없다.
#
# 무인 실행이라 --dangerously-skip-permissions 로 돈다. 티켓 PR을 열고 통합 브랜치로
# 머지까지 한다. 최종 base(develop)로는 안 나가므로 되돌리기는 통합 브랜치 reset 범위 안이다.
#
# 진행상황:
#   - Orca 보드 — 워크트리 status 가 in-progress(구현중) → in-review(리뷰중) → completed(구현완료).
#     스크립트가 in-progress 와 completed 를, 에이전트가 티켓 PR 개설 직후 in-review 를 찍는다.
#     completed 를 스크립트가 쥐는 이유: 에이전트의 자기신고보다 이슈 close 실측이 믿을 만하다.
#   - stdout — `##` 마커와 툴 이름만. 원본 이벤트는 ticket-<n>.jsonl.
#
# 주입: track-notes.md 에 쓰면 다음 읽기 지점(티켓 시작 / PR 본문 작성 직전)부터 반영된다.
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "사용법: $0 <티켓번호> [티켓번호...]" >&2
  exit 2
fi

for c in orca gh jq; do
  command -v "$c" >/dev/null || { echo "!!! $c 가 없다." >&2; exit 2; }
done
orca status >/dev/null 2>&1 || { echo "!!! Orca 런타임이 안 뜬다. 'orca open' 먼저." >&2; exit 2; }

cd "$(git rev-parse --show-toplevel)"
ROOT=$(pwd)

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
INTEGRATION=$(git rev-parse --abbrev-ref HEAD)
INTEGRATION_PR=$(gh pr list --repo "$REPO" --head "$INTEGRATION" --state open --json number -q '.[0].number // empty')

if [ -z "$INTEGRATION_PR" ]; then
  echo "!!! '$INTEGRATION' 를 head로 하는 열린 PR이 없다. 통합 브랜치에서 실행하거나 /track start 를 먼저 해라." >&2
  exit 2
fi

GITDIR=$(git rev-parse --git-common-dir)
case "$GITDIR" in /*) ;; *) GITDIR="$ROOT/$GITDIR" ;; esac
NOTES="$GITDIR/matt-context/track-notes.md"
GATES="$GITDIR/matt-context/repo-gates.md"
LOGDIR="$GITDIR/matt-context/ticket-runs/$INTEGRATION"
mkdir -p "$LOGDIR"

echo "repo=$REPO  통합브랜치=$INTEGRATION  통합PR=#$INTEGRATION_PR  티켓=$*"
echo "로그: $LOGDIR    주입: $NOTES"

# 레포별 검증 게이트. 있으면 프롬프트에 통째로 끼운다 — 이 스크립트를 레포 무관하게 유지하는 장치다.
if [ -f "$GATES" ]; then
  GATES_TEXT="## 이 레포의 검증 게이트 (정본)

$(cat "$GATES")"
  echo "게이트: $GATES"
else
  GATES_TEXT="## 이 레포의 검증 게이트 (정본)

(아직 없음 — package.json 과 CI 워크플로에서 직접 알아내고, 알아낸 것을 \`$GATES\` 에 적어 둘 것.)"
  echo "게이트: (없음 — 에이전트가 알아내서 $GATES 에 적는다)"
fi

# `##` 로 시작하는 에이전트 마커와 툴 이름만 남긴다. 툴 인자는 버린다.
RENDER='
  if .type=="assistant" then
    (.message.content[]?
      | if .type=="text" then (.text | select(startswith("##")))
        elif .type=="tool_use" then "    · \(.name)"
        else empty end)
  elif .type=="result" then "  ▪ result=\(.subtype) turns=\(.num_turns // "?")"
  else empty end'

for n in "$@"; do
  echo "=== 티켓 #$n 시작 $(date +%H:%M:%S) ==="

  # 매 티켓마다 새로 판다 — 앞 티켓의 스쿼시 머지가 origin/<통합> tip 을 옮겼다.
  git fetch -q origin

  # 티켓 브랜치명 = <통합>-{현존 최대 + 1}.
  # 두 가지를 견뎌야 한다:
  #  ① 살아있는 브랜치로 세면 안 된다 — 머지 시 --delete-branch 로 지워져 origin 에 안 남는다.
  #  ② orca 가 브랜치명을 제 방식대로 짓는다 — 사용자 프리픽스를 붙이고 '/' 를 '-' 로 바꾼다
  #     (실측: 원한 feature/RPB-10043-integration-7 → 실제 OhSeungWan/feature-RPB-10043-integration-7).
  #     그래서 접두사로 매칭하지 말고 '통합브랜치명(원형 또는 슬러그) + -숫자' 로 끝나는 것에서 숫자만 뽑는다.
  SLUG=$(printf '%s' "$INTEGRATION" | tr '/' '-')
  #  ③ 아직 push 안 된 진행 중 티켓도 세야 한다 — 로컬 브랜치는 공용 git dir 라 다른 워크트리 것도 보인다.
  maxn=$( { gh pr list --repo "$REPO" --base "$INTEGRATION" --state all --limit 200 \
              --json headRefName -q '.[].headRefName'
            git ls-remote --heads origin | sed 's#.*refs/heads/##'
            git branch --format='%(refname:short)'
          } | grep -E "(${INTEGRATION}|${SLUG})-[0-9]+\$" \
            | grep -oE '[0-9]+$' | sort -n | tail -1 || true )
  WANT_BRANCH="${INTEGRATION}-$(( ${maxn:-0} + 1 ))"

  # 티켓 전용 워크트리. 통합 브랜치 체크아웃과 파일이 안 겹친다.
  orca worktree create \
    --repo "path:$ROOT" \
    --name "$WANT_BRANCH" \
    --base-branch "origin/$INTEGRATION" \
    --issue "$n" \
    --comment "무인 러너 — 티켓 #$n" \
    --setup run --json >"$LOGDIR/ticket-$n.worktree.json"

  SHOW=$(orca worktree show --worktree "name:$WANT_BRANCH" --json)
  WT=$(printf '%s' "$SHOW" | jq -r '.result.worktree.path')
  GOT_BRANCH=$(printf '%s' "$SHOW" | jq -r '.result.worktree.branch | sub("^refs/heads/";"")')
  [ -n "$WT" ] && [ "$WT" != "null" ] || { echo "!!! 워크트리 경로를 못 읽었다." >&2; exit 1; }
  if [ "$GOT_BRANCH" != "$WANT_BRANCH" ]; then
    echo "  (주의: orca 가 브랜치를 '$GOT_BRANCH' 로 만들었다. 원한 이름은 '$WANT_BRANCH')"
  fi
  echo "  워크트리: $WT   브랜치: $GOT_BRANCH"

  # orca.yaml 이 없으면 setup hook 이 안 돈다 — 새 워크트리에 의존성이 없어 테스트가 죽는다.
  # node 레포면 node_modules 를 빌려준다. 아니면 아무 일도 안 한다.
  [ -d "$ROOT/node_modules" ] && [ ! -e "$WT/node_modules" ] && ln -s "$ROOT/node_modules" "$WT/node_modules"
  for f in .env .env.local .env.development; do
    [ -f "$ROOT/$f" ] && [ ! -e "$WT/$f" ] && ln -s "$ROOT/$f" "$WT/$f"
  done

  orca worktree set --worktree "path:$WT" --workspace-status in-progress >/dev/null

  (cd "$WT" && claude -p "$(cat <<EOF
티켓 #$n 을 끝까지 처리한다. 사람에게 물을 수 없는 무인 실행이다 — 승인 게이트는 자동 승인으로 간주하고 진행한다.

**너는 이미 티켓 워크트리 안에 있다.** 경로 \`$WT\`, 브랜치 \`$GOT_BRANCH\`, \`origin/$INTEGRATION\` 에서 딴 것이다.
/track ticket 의 절차 1(브랜치 생성)은 **건너뛴다.** 브랜치를 새로 파거나 갈아타지 마라.
\`node_modules\` 는 메인 체크아웃(\`$ROOT/node_modules\`)을 가리키는 심링크다 — 지우거나 재설치하지 마라.
타입체크가 모듈을 통째로 못 찾으면 그 심링크가 사라진 것이다(실측: #194 실행 중 소실).
\`ln -s "$ROOT/node_modules" "$WT/node_modules"\` 로 **다시 걸어라.** 설치를 새로 돌리지 마라.

단계를 넘어갈 때마다 \`## <단계명>\` 한 줄을 출력한다(예: \`## 구현중\`). 그게 사람이 보는 진행상황이다.

1. \`gh issue view $n\` 로 티켓을, \`gh pr view $INTEGRATION_PR\` 로 트랙 현황(티켓 표·리뷰 포인트·불가침 영역)을 읽는다.
   본문에 갱신 이력이 붙어 있으면 **가장 나중 절이 정본**이다 — 위쪽 서술과 어긋나면 나중 것을 따른다.
2. \`$NOTES\` 를 읽는다. '$INTEGRATION' 절에 취소선 없는 항목이 있으면 그게 티켓 본문보다 최신인 사실이다.
   그 사실이 이 티켓의 범위·계약·AC를 바꾸면 **바뀐 쪽으로 구현한다.**
3. mattpocock-skills 계열로 구현한다. 로직이 붙으면 tdd, 기존 동작이 깨지면 diagnosing-bugs.
4. 검증을 실측한다. **아래 「이 레포의 검증 게이트」 절이 정본이다.** 그 절이 비어 있으면
   \`package.json\` 스크립트와 CI 워크플로를 읽어 실제로 돌아가는 것을 고르고, 통과한 명령이 실제로
   변경 파일을 검사했는지까지 확인한다(설정이 안 걸려 무연산으로 통과하는 린터가 흔하다).
   새로 알아낸 게이트 사실이 있으면 마지막에 \`$GATES\` 에 한 줄로 추가한다.

$GATES_TEXT
5. **티켓 PR 본문을 쓰기 직전에 \`$NOTES\` 를 한 번 더 읽는다.** 구현하는 동안 새 항목이 붙었을 수 있다.
   범위를 뒤집는 항목이 새로 있으면 PR을 열지 말고 중단한다.
6. /track ticket 으로 티켓 PR 개설(브랜치는 이미 있다). base = $INTEGRATION.
7. PR을 연 직후 \`orca worktree set --worktree "path:$WT" --workspace-status in-review\` 를 실행한다.
8. \`gh pr checks <티켓PR> --watch\` 로 CI 통과 대기 후 \`gh pr merge <티켓PR> --squash --delete-branch\`.
9. /track merged 실행. dry-run 요약은 출력으로 남기되 승인 없이 일괄 실행한다.
10. \`$NOTES\` 에서 이번 티켓이 반영한 항목에 취소선과 \`(반영: #$n)\` 를 붙인다.

막히면(구현 불가·CI 실패·계약 미확정·티켓 본문이 서로 모순·범위가 티켓과 어긋남) 중단하고 이유를 출력한다.
그 경우 티켓 이슈 #$n 을 close 하지 않는다 — 그게 이 러너의 실패 신호다.
EOF
)" \
    --dangerously-skip-permissions \
    --output-format stream-json --verbose \
    2>"$LOGDIR/ticket-$n.err" ) \
    | tee "$LOGDIR/ticket-$n.jsonl" \
    | jq -r --unbuffered "$RENDER" || true

  # 게이트: /track merged 가 이슈를 닫았나. claude 의 exit code 는 작업 성공과 무관하다.
  state=$(gh issue view "$n" --repo "$REPO" --json state -q .state)
  if [ "$state" != "CLOSED" ]; then
    echo "!!! 티켓 #$n 미완료(이슈 $state). 중단." >&2
    echo "    워크트리 남겨 둔다: $WT" >&2
    echo "    로그: $LOGDIR/ticket-$n.jsonl  ·  stderr: $LOGDIR/ticket-$n.err" >&2
    exit 1
  fi

  orca worktree set --worktree "path:$WT" --workspace-status completed >/dev/null
  echo "=== 티켓 #$n 완료 $(date +%H:%M:%S) ==="
done

echo
echo "전부 완료. 통합 PR: gh pr view $INTEGRATION_PR --web"
echo "워크트리는 보드에 남겨 뒀다. 정리: orca worktree rm --worktree name:<브랜치명> --force"
