#!/usr/bin/env bash
#
# 티켓 자동 소진 러너 — 티켓 1장 = orca 워크트리 1개 = claude 프로세스 1개 = 컨텍스트 0에서 시작.
#
# 사용법: 통합 브랜치를 체크아웃한 워크트리에서 실행한다.
#   .git/shared-store/run-tickets.sh 193        (기존 레포는 .git/matt-context/)
#   .git/shared-store/run-tickets.sh 193 194 196 212 213
#
# 전제·진행상황 보는 자리·실패 읽는 법·함정은 grind 스킬의 SKILL.md 가 정본이다.
# 아래 주석은 코드가 왜 이 모양인지만 적는다.
#
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
# orca 는 repo 를 메인 체크아웃 경로로 등록한다. 이미 orca 워크트리 안에서 돌리면
# $ROOT(= --show-toplevel)는 등록 목록에 없어 repo_not_found 로 즉사한다.
# --git-common-dir 은 워크트리에서도 항상 메인 체크아웃의 .git 을 가리키므로 그 부모가 정답이다.
ORCA_REPO=$(dirname "$GITDIR")
# 스토어 디렉터리 — shared-store 가 정본, 기존 matt-context 스토어가 있으면 그대로 쓴다(shared-store link.sh 와 같은 해석).
STORE="$GITDIR/shared-store"
[ -d "$GITDIR/matt-context" ] && [ ! -d "$STORE" ] && STORE="$GITDIR/matt-context"
GATES="$STORE/repo-gates.md"
LOGDIR="$STORE/ticket-runs/$INTEGRATION"
mkdir -p "$LOGDIR"

# 머지 방식은 repo 설정에서 감지한다 — track 값 결정과 같은 축. 스쿼시 우선.
# (echo 보다 먼저 와야 한다 — set -u 라 미정의 참조 즉사)
MERGE_FLAG=$(gh repo view --json squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed \
  -q 'if .squashMergeAllowed then "--squash" elif .rebaseMergeAllowed then "--rebase" else "--merge" end')

echo "repo=$REPO  통합브랜치=$INTEGRATION  통합PR=#$INTEGRATION_PR  머지=$MERGE_FLAG  티켓=$*"
echo "로그: $LOGDIR    주입: 통합 PR #$INTEGRATION_PR 코멘트"

# 주입점 조회. 통합 PR 코멘트 중 리액션이 안 붙은 것 = 아직 아무 티켓도 처리하지 않은 항목.
# 커서 파일을 두지 않는 이유: 소진 상태가 데이터에 붙어 살아야 워크트리를 지워도 남고, PR UI에서 사람이 본다.
# FILTER 를 따로 두는 이유: self-check.sh 가 이 줄을 그대로 뽑아 검사한다 — 사본 검사는 본체를 고쳤을 때 거짓 통과를 낸다.
FILTER='.[] | select((.reactions["+1"] // 0) == 0 and (.reactions.eyes // 0) == 0)'
UNREAD="gh api repos/$REPO/issues/$INTEGRATION_PR/comments --paginate --jq '$FILTER | \"--- comment id=\\(.id) by=\\(.user.login)\\n\\(.body)\"'"

# 레포별 검증 게이트. 있으면 프롬프트에 통째로 끼운다.
if [ -f "$GATES" ]; then
  GATES_TEXT="## 이 레포의 검증 게이트 (정본)

$(cat "$GATES")"
  echo "게이트: $GATES"
else
  GATES_TEXT="## 이 레포의 검증 게이트 (정본)

(아직 없음 — package.json 과 CI 워크플로에서 직접 알아내고, 알아낸 것을 \`$GATES\` 에 적어 둘 것.)"
  echo "게이트: (없음 — 에이전트가 알아내서 $GATES 에 적는다)"
fi

# 구현 규율 — /grind setup 이 구운 파일이 있으면 그걸, 없으면 아래 기본값을 프롬프트에 끼운다.
# 조건부 한 줄 참조는 판이 무시한다(실측: 94판 중 스킬 로드 5판) — 실행은 프롬프트의 무조건 번호 단계가 하고,
# 절 이름 「구현 규율」·「자가 리뷰」 는 그 단계가 가리키는 고정 계약이다. 스킬 이름은 여기 하드코딩하지 않는다.
GUIDE="$STORE/impl-guide.md"
if [ -f "$GUIDE" ]; then
  GUIDE_TEXT="$(cat "$GUIDE")"
  echo "규율: $GUIDE"
else
  GUIDE_TEXT="## 구현 규율 (기본값 — /grind setup 으로 레포 맞춤 생성 가능)

판정 타입: 로직 | 버그수정 | UI·배선
- **로직**(새 계산·조건·상태 전이가 붙는다): 실패하는 테스트를 먼저 쓰고(red) 통과시킨다(green). 테스트는 공개 인터페이스에서, 한 번에 한 조각.
- **버그수정**(기존 동작이 틀렸다): 고치기 전에 증상이 드러나는 확인 방법을 만들고, 반증 가능한 가설 3개를 적어 순위대로 검증한다.
- **UI·배선**(마크업·스타일·문구·단순 연결): 바로 구현한다.

## 자가 리뷰

\`git diff origin/$INTEGRATION...HEAD\` 를 두 축으로 본다 — 스펙(티켓이 요구한 것이 빠짐없이, 요구 밖 변경 없이), 표준(이 레포의 기존 컨벤션과 어긋난 곳)."
  echo "규율: (기본값 — /grind setup 으로 레포 맞춤 생성 가능)"
fi

# `##` 로 시작하는 에이전트 마커와 결과 한 줄만 남긴다.
# 툴 이름을 안 내보내는 이유: stdout 은 오케스트레이터 세션의 컨텍스트를 먹는 자리다.
# 사후 진단은 원본 .jsonl 에서 한다 (거기엔 툴 인자까지 다 있다).
#
# -R + fromjson? 인 이유: claude 가 stream-json 과 **같은 stdout 으로** 비-JSON 줄을 섞어 내보낸다
# (실측: MCP 의 "Client.listTools() called but server does not advertise tools capability" 경고).
# -R 없이 돌리면 jq 가 그 줄에서 죽고, EPIPE 가 tee 를 거쳐 claude 까지 올라가 티켓이 통째로 끊긴다(실측: exit 144).
RENDER='
  fromjson? // empty
  | if .type=="assistant" then
      (.message.content[]? | select(.type=="text") | .text | select(startswith("##")))
    elif .type=="result" then "  ▪ result=\(.subtype) turns=\(.num_turns // "?")"
    else empty end'

for n in "$@"; do
  echo "=== 티켓 #$n 시작 $(date +%H:%M:%S) ==="

  # 매 티켓마다 새로 판다 — 앞 티켓의 스쿼시 머지가 origin/<통합> tip 을 옮겼다.
  git fetch -q origin

  # 티켓 브랜치명 = <통합>-{현존 최대 + 1}.
  # 세는 곳이 셋인 이유(삭제된 브랜치 · orca 의 이름 변형 · 아직 push 안 된 티켓)는 SKILL.md 함정 참조.
  SLUG=$(printf '%s' "$INTEGRATION" | tr '/' '-')
  maxn=$( { gh pr list --repo "$REPO" --base "$INTEGRATION" --state all --limit 200 \
              --json headRefName -q '.[].headRefName'
            git ls-remote --heads origin | sed 's#.*refs/heads/##'
            git branch --format='%(refname:short)'
          } | grep -E "(${INTEGRATION}|${SLUG})-[0-9]+\$" \
            | grep -oE '[0-9]+$' | sort -n | tail -1 || true )
  WANT_BRANCH="${INTEGRATION}-$(( ${maxn:-0} + 1 ))"

  # 티켓 전용 워크트리. 통합 브랜치 체크아웃과 파일이 안 겹친다.
  orca worktree create \
    --repo "path:$ORCA_REPO" \
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

  # orca.yaml 이 없으면 setup hook 이 안 돌아 새 워크트리에 의존성이 없다. node 레포면 빌려준다.
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

1. \`gh issue view $n --comments\` 로 티켓을, \`gh pr view $INTEGRATION_PR\` 로 트랙 현황(티켓 표·트랙 결정·리뷰 포인트·열린 질문)을 읽는다.
   본문에 갱신 이력이 붙어 있으면 **가장 나중 절이 정본**이다 — 위쪽 서술과 어긋나면 나중 것을 따른다.
   「트랙 결정」 절은 앞 티켓들이 이미 닫은 결정이다 — 다시 열지 마라. 「열린 질문」은 아직 안 닫힌 것이니 네가 닫지도 마라.
2. **이슈 본문·코멘트와 통합 PR 본문이 가리키는 외부 문서(노션 계약·응답 스펙 등)를 링크 따라가 읽는다.** 1단만 따라간다.
   못 읽으면(MCP 미연결·권한·토큰 만료) **그 사실을 출력한다.** 계약을 못 읽은 채 추측으로 메우지 마라 —
   그 링크가 이 티켓의 계약이면 거기서 중단한다.
3. 주입점을 읽는다 — 통합 PR 코멘트 중 **리액션이 안 붙은 것**:
   \`$UNREAD\`
   나오는 항목은 티켓 본문보다 최신인 사실이다. 범위·계약·AC를 바꾸면 **바뀐 쪽으로 구현한다.**
4. 아래 「구현 규율」 절의 판정 타입 중 하나로 티켓 성격을 판정해 한 줄 출력한다: \`## 판정: <타입>\`
   그 타입의 지침대로 구현한다. 지침이 스킬 로드를 시키면 Skill 툴로 로드한 뒤 구현한다.

$GUIDE_TEXT
5. 검증을 실측한다. **아래 「이 레포의 검증 게이트」 절이 정본이다.** 그 절이 비어 있으면
   \`package.json\` 스크립트와 CI 워크플로를 읽어 실제로 돌아가는 것을 고르고, 통과한 명령이 실제로
   변경 파일을 검사했는지까지 확인한다(설정이 안 걸려 무연산으로 통과하는 린터가 흔하다).
   새로 알아낸 게이트 사실이 있으면 마지막에 \`$GATES\` 에 한 줄로 추가한다.

$GATES_TEXT
6. 티켓 PR 을 열기 전에 위 「자가 리뷰」 절을 실행한다. 스펙 출처는 티켓 이슈 #$n.
   명백한 위반은 지금 고치고, 판단성 지적과 스펙 미달은 티켓 PR 본문에 「리뷰 포인트」 절로 남긴다.
7. **티켓 PR 본문을 쓰기 직전에 3항을 한 번 더 돈다.** 구현하는 동안 새 코멘트가 붙었을 수 있다. 새 항목마다 셋 중 하나로 판정한다:
   - **이번 PR의 코드를 틀린 것으로 만든다** → PR을 열지 말고 중단한다.
   - **이번 범위에 안 닿는 추가 작업이다** → 그 코멘트에 \`eyes\` 리액션을 달고 통합 PR 본문 「열린 질문」에 한 줄 남긴 뒤 **PR을 열고 진행한다.** 티켓을 새로 만들지 마라.
   - **애매하다** → 중단한다.
8. /track ticket 으로 티켓 PR 개설(브랜치는 이미 있다). base = $INTEGRATION.
9. PR을 연 직후 \`orca worktree set --worktree "path:$WT" --workspace-status in-review\` 를 실행한다.
10. \`gh pr checks <티켓PR> --watch\` 로 CI 통과 대기 후 \`gh pr merge <티켓PR> $MERGE_FLAG --delete-branch\`.
11. /track merged 실행. dry-run 요약은 출력으로 남기되 승인 없이 일괄 실행한다.
12. 소진 표시. 3항에서 읽어 **반영한** 코멘트마다:
    \`gh api -X POST repos/$REPO/issues/comments/<id>/reactions -f content=+1\`
    그 내용이 이 티켓에서 끝나지 않고 **트랙 전체에 계속 유효한 사실**이면(계약 확정·설계 판정 등)
    통합 PR 본문 「트랙 결정」 절에 한 줄로 승격한다 — 뒤 티켓은 코멘트가 아니라 그 절을 읽는다.
    지시가 아니라 사실로 적는다("~하지 마"가 아니라 "계약이 X로 확정됐다").

막히면(구현 불가·CI 실패·계약 미확정·계약 문서를 못 읽음·티켓 본문이 서로 모순·범위가 티켓과 어긋남) 중단하고 이유를 출력한다.
블로커를 경중으로 나눠 스스로 우회하지 마라 — 막히면 전부 정지다.
그 경우 티켓 이슈 #$n 을 close 하지 않는다 — 그게 이 러너의 실패 신호다.
EOF
)" \
    --model "${GRIND_MODEL:-claude-opus-5}" \
    --dangerously-skip-permissions \
    --output-format stream-json --verbose \
    2>"$LOGDIR/ticket-$n.err" ) \
    | tee "$LOGDIR/ticket-$n.jsonl" \
    | { jq -rR --unbuffered "$RENDER" || cat >/dev/null; } || true
  # jq 가 그래도 죽으면 cat 이 남은 stdin 을 드레인한다. 렌더러 하나 죽었다고
  # producer(claude)를 EPIPE 로 끊어 티켓을 날리지 않는다 — 렌더는 곁다리고 원본은 .jsonl 에 이미 있다.

  # 유일한 판정: /track merged 가 이슈를 닫았나. claude 의 exit code 는 작업 성공과 무관하다.
  state=$(gh issue view "$n" --repo "$REPO" --json state -q .state)
  if [ "$state" != "CLOSED" ]; then
    echo "!!! 티켓 #$n 미완료(이슈 $state). 중단." >&2
    echo "    워크트리 남겨 둔다: $WT" >&2
    echo "    로그: $LOGDIR/ticket-$n.jsonl  ·  stderr: $LOGDIR/ticket-$n.err" >&2
    exit 1
  fi

  orca worktree set --worktree "path:$WT" --workspace-status completed >/dev/null
  # 성공한 티켓의 워크트리는 바로 지운다 — 브랜치는 머지로 이미 삭제됐고, 재개가 필요한 건 실패 티켓뿐이다.
  orca worktree rm --worktree "path:$WT" --force >/dev/null \
    || echo "  (주의: 워크트리 정리 실패 — 수동: orca worktree rm --worktree \"path:$WT\" --force)"
  echo "=== 티켓 #$n 완료 $(date +%H:%M:%S) — 워크트리 정리됨 ==="
done

echo
echo "전부 완료. 통합 PR: gh pr view $INTEGRATION_PR --web"
echo "워크트리는 티켓 완료마다 정리했다 — 남아 있으면 실패 티켓 것이다."
