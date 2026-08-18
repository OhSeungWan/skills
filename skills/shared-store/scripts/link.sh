#!/usr/bin/env bash
# 개인 문서를 공용 git dir 스토어로 심링크한다.
# 커밋되지 않으면서 모든 워크트리가 같은 파일을 공유하게 만든다. 멱등하다.
#
# 사용법: 워크트리 루트에서
#   bash <스킬>/scripts/link.sh
#
# 스토어가 없으면 만든다: 디렉토리 + git init(이력) + 기본 manifest.
# 링크할 항목은 <스토어>/manifest 가 정한다. 형식은 한 줄에 하나:
#   <워크트리 상대경로>:<스토어 경로>[:gitignore]
# skip:<글롭> 줄은 그 이름의 워크트리를 검사·링크 대상에서 뺀다(임시 에이전트 워크트리 등).
# 세 번째 칸이 gitignore 면 그 경로는 커밋된 .gitignore 가 담당한다고 보고
# info/exclude 에 넣지 않는다. 없으면 info/exclude 에 등록한다.
set -e

common=$(git rev-parse --git-common-dir)
common_abs=$(cd -P "$common" && pwd)
root=$(git rev-parse --show-toplevel)

# 기존 matt-context 스토어가 있으면 그걸 계속 쓴다 (이사 없음)
store="$common_abs/shared-store"
[ -d "$common_abs/matt-context" ] && [ ! -d "$store" ] && store="$common_abs/matt-context"

if [ ! -d "$store" ]; then
  mkdir -p "$store"
  echo "created: $store"
fi

if [ ! -e "$store/.git" ]; then
  git init -q "$store"
  echo "git init: $store (이제 개인 문서에 이력이 남는다 — 커밋은 save 가 한다)"
fi

manifest="$store/manifest"
if [ ! -f "$manifest" ]; then
  cat > "$manifest" <<'DEFAULT'
# <워크트리 상대경로>:<스토어 경로>[:gitignore]
# skip:<글롭> — 그 이름의 워크트리는 검사·링크 대상에서 뺀다
skip:agent-*
CONTEXT.md:CONTEXT.md
CLAUDE.local.md:CLAUDE.local.md
docs/agents:agents
docs/adr:adr
DEFAULT
  echo "created: manifest (기본 4항목)"
fi

# 세션 시작 훅(~/.local/bin/matt-context-relink)이 플러그인 경로 없이 찾을 수 있도록
# 링커 사본을 스토어에 심는다. 훅은 스킬이 아니라 이 사본을 실행한다.
self="$(cd -P "$(dirname "$0")" && pwd)/$(basename "$0")"
if [ "$self" != "$store/link.sh" ] && ! cmp -s "$self" "$store/link.sh"; then
  cp "$self" "$store/link.sh"
  echo "installed: link.sh (세션 시작 훅이 실행할 링커 사본)"
fi

rels=()
excludes=()
while IFS= read -r line; do
  case "$line" in ''|'#'*|'skip:'*) continue ;; esac
  IFS=: read -r rel src mode <<<"$line"
  [ -n "$rel" ] && [ -n "$src" ] || { echo "WARN: manifest 줄을 읽을 수 없다: $line"; continue; }
  rels+=("$rel")
  [ "$mode" = "gitignore" ] || excludes+=("$rel")

  target="$store/$src"
  link="$root/$rel"

  if [ ! -e "$target" ]; then
    echo "skip: $rel (스토어에 $src 없음)"
    continue
  fi

  # 이미 심링크면 갈아끼우고, 실제 파일/디렉토리면 손대지 않고 경고한다.
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    if [ -d "$link" ] && [ -n "$(ls -A "$link" 2>/dev/null)" ]; then
      echo "WARN: $rel 이 내용 있는 실제 디렉토리다. adopt 으로 스토어에 합쳐라."
      continue
    fi
    if [ -f "$link" ]; then
      echo "WARN: $rel 이 실제 파일이다(추적 중일 수 있다). adopt 으로 스토어에 합쳐라."
      continue
    fi
    rmdir "$link" 2>/dev/null || true
  fi

  mkdir -p "$(dirname "$link")"
  ln -sfn "$target" "$link"
  echo "linked: $rel -> $target"
done < "$manifest"

# 공용 + 워크트리 gitdir 양쪽 info/exclude 에 등록 (심링크가 untracked 로 안 잡히게)
if [ ${#excludes[@]} -gt 0 ]; then
  for ex in "$common_abs/info/exclude" "$(cd -P "$(git rev-parse --git-dir)" && pwd)/info/exclude"; do
    mkdir -p "$(dirname "$ex")"
    for pat in "${excludes[@]}"; do
      grep -qxF "$pat" "$ex" 2>/dev/null || echo "$pat" >> "$ex"
    done
  done
fi

echo
for pat in "${rels[@]}"; do
  if git check-ignore -q "$pat" 2>/dev/null; then
    echo "ignored OK: $pat (커밋 안 됨)"
  else
    echo "WARN: $pat 이 ignore 되지 않는다 — 추적 중인지 확인하라 (git ls-files $pat)"
  fi
done
