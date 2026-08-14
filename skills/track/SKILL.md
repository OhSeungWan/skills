---
name: track
description: 티켓 여러 장으로 진행하는 트랙의 브랜치·PR 라이프사이클. 트랙 착수(통합 브랜치·통합 PR 개설), 티켓 브랜치·티켓 PR 생성, 티켓 PR 머지 직후 손처리가 필요할 때 사용. 사용자가 "트랙 시작하자", "티켓 PR 올려", "머지됐다"고 말할 때, 또는 에이전트가 직접 티켓 PR을 머지했을 때. /track [start|ticket|merged]
---

# track

티켓 여러 장짜리 트랙을 3층 브랜치로 운용한다. 분기마다 **판정 → 절차 → 함정** 순서를 지킨다.

```
최종 base                      예: feature/renewal/main — default 브랜치가 아닐 수 있다
  └─ 통합 브랜치                트랙 전체를 모으는 장기 브랜치. 통합 PR을 최종 base로 열어 두고
      │                        본문(트랙 대시보드)을 산 문서로 갱신한다
      └─ 티켓 브랜치 <통합>-{n}  실작업 커밋이 쌓이는 곳. 통합 브랜치로 티켓 PR
```

## 값 결정 (모든 분기 공통, 맨 먼저)

repo에 브랜치/PR 관례 문서가 있으면(CLAUDE.md · CONVENTIONS.md · docs/agents/* · docs/project-context.md 류) 그 값이 우선. 다음이 감지, 감지 불가면 인자·질문.

| 값 | 결정 방법 |
| --- | --- |
| 최종 base | 인자/관례 문서. default 브랜치라고 단정하지 말 것 — `gh repo view --json defaultBranchRef`와 비교하고, 다르면 ③의 이슈 수동 close 규칙이 켜진다 |
| 통합 브랜치명 | 인자/관례 문서. 없으면 사용자에게 질문 |
| 티켓 브랜치명 | 기본 `<통합>-{n}` (n = 현존 최대 + 1). 관례 문서로 오버라이드 |
| 머지 방식 | `gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` + 최근 머지 PR 실측. 스쿼시면 ②의 base 어긋남 경고가 상시 해당 |
| PR 템플릿 | `.github/pull_request_template.md` 있으면 그 절 구조 안에 대시보드 4블록 배치 |
| 백로그 미러(Notion 등) · 라벨 | 관례 문서에 있으면 따르고, 없으면 조용히 건너뛴다 |

## 분기 판별

인자가 `start`/`ticket`/`merged`면 그 분기로 간다. 인자가 없으면 현재 브랜치·열린 PR·직전 머지 여부를 실측해 "지금 상태는 ②로 보인다 — 맞나?"라고 **묻고 시작한다.** 세 분기 모두 외부에 보이는 것(브랜치·PR·이슈·코멘트)을 만들므로, 감지 결과는 제안까지만 쓴다.

## ① start — 트랙 시작

**판정: 예상 티켓 수가 2장 이상인가.** 스펙 이슈의 분할 계획으로 판단하고, 없거나 애매하면 사용자에게 묻는다. merge-base 실측이나 단발 티켓 PR 선례는 판정 근거가 아니다 — 그걸 근거로 오판한 실측 사례가 이 스킬의 기원이다. 1장이면 통합 브랜치 없이 일반 PR로 끝낸다.

절차:

1. base tip에서 통합 브랜치 생성.
2. **빈 시작 커밋** — `git commit --allow-empty -m "chore: <트랙명> 트랙 시작"`. 통합 브랜치가 base tip과 동일하면 GitHub이 통합 PR을 만들지 못하고, 이미 열린 PR도 자동 close 후 재오픈을 거부한다(`Could not open the pull request (reopenPullRequest)`). 다른 feature 브랜치 팁을 물고 분기한 트랙은 이 문제가 없다 — 최종 base에서 바로 딴 트랙만 해당.
3. push 후 통합 PR 개설(base = 최종 base). 본문 = 트랙 대시보드.

**트랙 대시보드 4블록 — 존재를 강제한다:** ⑴ 티켓 표(번호·상태·머지 SHA) ⑵ 리뷰 포인트 ⑶ 배포 전 사람 몫 ⑷ 열린 질문. PR 템플릿이 있으면 그 절 구조 안에 배치하고, 블록 내부 양식은 자유.

**승격** — 단발로 시작한 PR이 트랙으로 커지면: 통합 브랜치 신설(빈 시작 커밋 포함) → 기존 PR을 `gh pr edit <n> --base <통합>`으로 retarget → 통합 PR 개설.

완료 기준: 통합 PR이 열려 있고 본문에 4블록이 있다.

## ② ticket — 티켓 브랜치·티켓 PR

작업 커밋은 티켓 브랜치에만 쌓는다. 통합 브랜치는 머지로만 자란다.

절차:

1. `git fetch` → `git branch <통합>-{n} origin/<통합>` — **로컬 통합 브랜치가 아니라 origin에서 딴다.** 앞 티켓이 스쿼시 머지되면 로컬 통합 브랜치가 뒤처져 base가 어긋난다.
2. 작업 커밋. (이미 다른 브랜치에 쌓았으면 cherry-pick으로 옮긴다.)
3. push 전 `git diff origin/<통합>...HEAD --stat` — 파일 수가 티켓 범위와 일치하는지 실측.
4. 티켓 PR 개설: base = 통합 브랜치.

**복구 — 작업 커밋을 통합 브랜치에 직접 쌓았을 때**(티켓 PR이 비거나 통합 PR에 섞인다):
`git branch <티켓브랜치> HEAD` → 통합 브랜치 `git reset --hard <base tip>` → `git push --force-with-lease` → 빈 시작 커밋(없었다면) → PR 재개설.

머지가 막혀 보일 때: `gh pr view <n> --json mergeable,mergeStateStatus,reviewDecision` — `MERGEABLE`/`BLOCKED`는 충돌이 아니라 리뷰·체크 게이트다. 충돌은 `CONFLICTING`/`DIRTY`로 나타나며, 스택에서는 대개 부모 PR 쪽이다.

완료 기준: 티켓 PR이 통합 브랜치를 base로 열려 있고, diff 파일 수가 티켓 범위와 일치한다.

## ③ merged — 티켓 PR 머지 후 손처리

빠뜨리면 트랙 대시보드가 죽은 문서가 된다. 흐름: **dry-run 요약 → 승인 1회 → 일괄 실행 → 결과 보고.** 항목마다 따로 묻지 않는다.

dry-run 요약에 담을 것: close할 이슈 번호, 통합 PR 본문 변경안, 달 코멘트 문안, **삭제할 원격 브랜치**(스쿼시 자동삭제 설정이면 이미 없음 — 확인해서 표기), 정답지(오라클) 갱신안(관례 문서가 지정한 경우). 승인 후:

1. 티켓 이슈 close — base가 default 브랜치가 아니면 `Closes #N`이 동작하지 않는다. 완료 코멘트 + `gh issue close <n>`.
2. 통합 PR 본문 갱신 — 티켓 표에 ✅·머지 SHA 기록, 규모 재실측(`git diff <base tip>..HEAD --stat`).
3. 스펙 이슈에 진행 코멘트.
4. **정답지(오라클) 갱신** — 관례 문서(CLAUDE.md · docs/agents/* 류)가 이 트랙의 정답지 문서와 갱신 스킬을 지정하면, 머지된 구현이 정답지와 다르게 착지했는지 확인하고 지정된 스킬로 갱신한다. 지정이 없으면 조용히 건너뛴다.
5. 백로그 미러 상태 동기화(관례에 있으면).
6. 티켓 브랜치 정리 — 원격 삭제 여부 확인 후 로컬도 삭제.
7. 다음 티켓 차단 해제 코멘트. 다음 티켓이 아직 티켓화 안 됐으면 사용자에게 알린다.

완료 기준: 7항목 각각의 실행 결과 또는 skip 사유가 보고에 있다.
