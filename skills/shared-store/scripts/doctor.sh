#!/usr/bin/env bash
# 스토어와 모든 워크트리의 링크 상태를 실측한다. 진단만 하고 고치지 않는다.
#
# 사용법: 이 repo 의 아무 워크트리에서
#   bash <스킬>/scripts/doctor.sh
#
# 판정 4종:
#   tracked   추적 중인 실제 파일이라 링크가 skip된다 (adopt 대상)
#   diverged  추적은 안 되지만 실제 파일·다른 곳을 가리키는 링크가 있다
#   missing   링크가 없다 (link 대상)
#   exposed   링크는 맞지만 ignore 되지 않는다 (커밋될 위험)
# 문제가 하나라도 있으면 exit 1.
set -e

# 심링크 대상 비교용 — 디렉토리만 물리 경로로 펴서 /var 와 /private/var 를 같게 만든다
canon() {
  local d b
  d=$(dirname "$1"); b=$(basename "$1")
  [ -d "$d" ] && d=$(cd -P "$d" && pwd)
  printf '%s/%s\n' "$d" "$b"
}

common_abs=$(cd -P "$(git rev-parse --git-common-dir)" && pwd)
store="$common_abs/shared-store"
[ -d "$common_abs/matt-context" ] && [ ! -d "$store" ] && store="$common_abs/matt-context"

if [ ! -d "$store" ]; then
  echo "스토어 없음: $store — link 로 만든다"
  exit 1
fi

manifest="$store/manifest"
if [ ! -f "$manifest" ]; then
  echo "manifest 없음: $manifest — link 가 기본값으로 만든다"
  exit 1
fi

# 스토어 자체 상태
state="이력 없음(git init 필요 — link)"
if [ -e "$store/.git" ]; then
  dirty=$(git -C "$store" status --porcelain | wc -l | tr -d ' ')
  state="이력 OK, 커밋 안 된 변경 $dirty"
  if git -C "$store" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    ahead=$(git -C "$store" rev-list --count '@{u}..HEAD')
    state="$state, 미푸시 $ahead"
  else
    state="$state, 리모트 없음"
  fi
fi
echo "스토어: $store"
echo "        $state"

items=()
skips=()
while IFS= read -r line; do
  case "$line" in
    ''|'#'*) continue ;;
    'skip:'*) skips+=("${line#skip:}"); continue ;;
  esac
  items+=("$line")
done < "$manifest"

problems=()
ok=0
checked=0
skipped=0

while IFS= read -r wtline; do
  case "$wtline" in 'worktree '*) ;; *) continue ;; esac
  wt="${wtline#worktree }"
  name=$(basename "$wt")
  skipped_wt=""
  for glob in "${skips[@]}"; do
    case "$name" in $glob) skipped_wt=1 ;; esac
  done
  if [ -n "$skipped_wt" ]; then
    skipped=$((skipped + 1))
    continue
  fi
  if [ ! -d "$wt" ]; then
    problems+=("$(printf '%-9s %-34s %s' missing "$name" '워크트리 경로가 없다 — git worktree prune')")
    continue
  fi
  for item in "${items[@]}"; do
    IFS=: read -r rel src mode <<<"$item"
    [ -n "$rel" ] && [ -n "$src" ] || continue
    checked=$((checked + 1))
    link="$wt/$rel"
    target="$store/$src"
    verdict=""
    note=""
    if [ -L "$link" ]; then
      actual=$(readlink "$link")
      if [ "$(canon "$actual")" = "$(canon "$target")" ]; then
        if git -C "$wt" check-ignore -q -- "$rel" 2>/dev/null; then
          ok=$((ok + 1))
        else
          verdict=exposed; note="ignore 안 됨 — link 재실행"
        fi
      else
        verdict=diverged; note="다른 곳을 가리킨다: $actual"
      fi
    elif [ -e "$link" ]; then
      if [ -n "$(git -C "$wt" ls-files -- "$rel" 2>/dev/null)" ]; then
        verdict=tracked; note="추적 중 — adopt"
      else
        verdict=diverged; note="추적 안 되는 실제 파일 — adopt 로 스토어에 합쳐라"
      fi
    else
      verdict=missing; note="link"
    fi
    [ -n "$verdict" ] && problems+=("$(printf '%-9s %-34s %-16s %s' "$verdict" "$name" "$rel" "$note")")
  done
done < <(git worktree list --porcelain)

echo "검사: $checked (항목 ${#items[@]} × 워크트리)${skipped:+, 건너뜀 $skipped (manifest skip)}"
echo

if [ ${#problems[@]} -eq 0 ]; then
  echo "정상 $ok — 전부 스토어를 가리키고 ignore 된다"
  exit 0
fi

echo "문제 ${#problems[@]}:"
for p in "${problems[@]}"; do echo "  $p"; done
echo
echo "정상 $ok"
exit 1
