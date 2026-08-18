#!/usr/bin/env bash
# link.sh · doctor.sh 자기검사. 임시 repo 를 만들어 판정 4종이 실제로 나오는지 본다.
# 사용법: bash tests/test_link_doctor.sh
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
link="$here/../scripts/link.sh"
doctor="$here/../scripts/doctor.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0
check() { # check <설명> <기대 문자열> <실제 출력>
  if printf '%s' "$3" | grep -qF "$2"; then echo "ok   — $1"; else echo "FAIL — $1 (기대: $2)"; fail=1; fi
}

git init -q "$tmp/main"
cd "$tmp/main"
git config user.email t@example.com; git config user.name t
mkdir -p docs/adr; echo x > docs/adr/0001-x.md; echo readme > README.md
git add -A; git commit -qm init
git worktree add -q ../wt2 -b wt2

out=$(bash "$link")
check "스토어 부트스트랩" "git init:" "$out"
check "링커 사본을 스토어에 심는다" "installed: link.sh" "$out"
check "스토어에 없는 항목은 skip" "skip: CONTEXT.md" "$out"

store="$tmp/main/.git/shared-store"
check "기본 manifest 에 skip 글롭" "skip:agent-*" "$(cat "$store/manifest")"

out=$(bash "$doctor" || true)
check "추적 파일을 tracked 로 판정" "tracked" "$out"
check "링크 없음을 missing 으로 판정" "missing" "$out"

# 스토어를 채우고 추적 파일을 입양한 뒤 재링크하면 정상이 된다
echo "# 용어집" > "$store/CONTEXT.md"
echo "# local" > "$store/CLAUDE.local.md"
mkdir -p "$store/agents" "$store/adr"; echo a > "$store/agents/domain.md"
mv docs/adr/0001-x.md "$store/adr/0001-x.md"; git rm -q --cached docs/adr/0001-x.md; rmdir docs/adr
git commit -qm "adopt docs/adr"
bash "$link" >/dev/null
# 다른 워크트리는 삭제 커밋을 받은 뒤에야 tracked 에서 벗어난다 (git rm --cached 는 브랜치 단위)
sha=$(git rev-parse HEAD)
(cd ../wt2 && git reset -q --hard "$sha" && bash "$link" >/dev/null)
out=$(bash "$doctor" || true)
check "입양·재링크 후 문제 없음" "정상 8 —" "$out"

# 심링크를 실제 파일로 바꾸면 갈라짐으로 잡힌다
rm CONTEXT.md; echo "손으로 쓴 것" > CONTEXT.md
out=$(bash "$doctor" || true)
check "실제 파일을 diverged 로 판정" "diverged" "$out"

# 세션 시작 훅은 스토어에 심긴 사본을 실행해 새 워크트리를 복구한다
hook="${RELINK:-$HOME/.local/bin/matt-context-relink}"
if [ -x "$hook" ]; then
  git worktree add -q ../wt3 -b wt3
  (cd ../wt3 && "$hook" </dev/null >/dev/null 2>&1) || true
  if [ -L "../wt3/CONTEXT.md" ]; then echo "ok   — 훅이 새 워크트리를 자동 복구"; else echo "FAIL — 훅이 새 워크트리를 자동 복구"; fail=1; fi
  git worktree remove --force ../wt3
else
  echo "skip — 훅 없음 ($hook)"
fi

# skip 글롭이 워크트리를 검사에서 뺀다
git worktree add -q ../agent-tmp -b agent-tmp
out=$(bash "$doctor" || true)
check "skip 글롭이 워크트리를 건너뜀" "건너뜀 1" "$out"

exit $fail
