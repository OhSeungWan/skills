---
name: autopilot
description: BMAD 프로젝트 하나를 조사→기획→구현(bmad-loop)→검증→출시까지 사람 없이 끝까지 민다. `claude -p` 세션을 셸 루프로 반복 띄우고 STATUS.md를 체크포인트로 이어받아 컨텍스트 한계를 우회한다. 사용자가 "무인으로 끝까지 밀어줘", "autopilot 세팅해줘", "자동으로 출시까지"라고 말할 때, 돌던 루프가 죽어 재개할 때(resume), 상태를 볼 때(status). /autopilot [setup|run|status|resume]
---

# autopilot

BMAD 스킬 체인 전체를 **사람 없이** 돈다. 세션 1개 = 큰 단계 1개. 세션이 끝나면 셸 루프가 5분 뒤 새 세션을 띄우고, 새 세션은 `STATUS.md`만 읽고 이어받는다.

**이 스킬의 존재 이유는 컨텍스트다.** 기획 문서 6개와 스토리 60개를 한 세션에서 이어 하면 요약(compaction)이 몇 번 일어나고 앞서 정한 값이 흐려진다. `grind`가 티켓 단위로 하는 일을 프로젝트 전체 단위로 한다.

**성립 근거는 셋이다.** ⑴ `STATUS.md` 첫 줄 `STATE:`와 단계 표가 상태 저장소다. ⑵ 구현 구간은 `bmad-loop`이 스토리마다 새 세션을 띄우므로 감시 세션은 이벤트 처리만 한다. ⑶ 사람 몫(계정·결제·서명)은 `HUMAN_TODO.md`로 분리해 그것에 의존하지 않는 일을 계속한다.

배관은 [`scripts/autopilot.sh`](scripts/autopilot.sh), 프롬프트 골격은 [`templates/AUTOPILOT.md`](templates/AUTOPILOT.md), 완성 예시는 [`examples/mobile-game-3x.md`](examples/mobile-game-3x.md)(모바일 게임 3종 순차 출시 — 실측으로 돌린 버전).

## 이 스킬이 하지 않는 것

- **BMAD·bmad-loop을 설치하지 않는다.** `npx bmad-method install`과 `/bmad-loop-setup`이 선행이다.
- **사람 몫을 대신하지 않는다.** 스토어 계정·결제·서명키·심사 제출 클릭은 `HUMAN_TODO.md`에 쌓이고 사람이 처리한다.
- **두 프로젝트를 동시에 돌리지 않는다.** `_bmad-output/`과 `sprint-status.yaml`이 하나뿐이다. 여러 결과물이 목표면 순차 규칙을 프롬프트에 넣는다(예시 파일의 "게임 순차 진행 규칙" 참조).
- **에스컬레이션을 사람에게 넘기지 않는다.** CRITICAL이면 감시 세션이 PRD·아키텍처를 근거로 스스로 결정하고 ADR을 남긴다. `bmad-loop-resolve`는 대화형이라 안 쓴다.

## 전제 — 하나라도 없으면 멈추고 무엇이 없는지 보고한다

1. `_bmad/` 있음 (BMAD 설치됨). `_bmad/bmm/config.yaml`에 `implementation_artifacts` 경로.
2. `bmad-loop --version` 응답하고 `.bmad-loop/policy.toml` 있음 (`bmad-loop init --project . --cli claude` 완료).
3. **사람이 `claude`를 이 프로젝트에서 한 번 열어 workspace trust와 hooks approval dialog를 수락했음.** 띄워진 세션은 dialog를 못 넘긴다 — 실측: 첫 스토리 dev 세션이 trust dialog에서 crash, bmad-loop이 PAUSED. (감시 세션이 resume해서 살아났지만 시간 낭비.)
4. git worktree clean. `bmad-loop validate`가 이걸 본다.
5. 사용자가 무인 실행을 승인했음. 세션은 `--dangerously-skip-permissions`로 돌고 commit·설치·빌드를 자동으로 한다. 승인은 setup 때 한 번.

## setup — 프롬프트를 굽고 배관을 놓는다

`/autopilot setup`.

1. `scripts/autopilot.sh`를 프로젝트 루트에 복사한다. 이미 있고 스킬 저장소 것과 다르면(`cmp -s`) 갱신한다 — 사본이 낡으면 이미 고친 함정이 되살아난다.
2. `.gitignore`에 `.autopilot.log`, `.autopilot.pid` 추가.
3. `templates/AUTOPILOT.md`를 프로젝트 루트 `AUTOPILOT.md`로 복사하고 **`<!-- 프로젝트별 -->` 표시된 절만** 사용자와 채운다. 물을 것: 임무 한 문단과 "완료"의 정의, 결과물 개수(2개 이상이면 순차 규칙), Phase 3 검증 목록, Phase 4 사람 몫 후보, 완성도 기준. **재개 규칙·작업 원칙·Phase 2는 손대지 않는다** — 실측으로 고친 문장들이다.
4. 전제 1~5를 실측하고 빠진 것을 보고한다. 특히 3은 사람에게 "지금 `claude` 한 번 열었다 닫아 달라"고 명시한다.
5. commit. `bmad-loop validate`의 "worktree not clean" FAIL은 이 commit이 없앤다. "sprint-status.yaml not found"는 정상 — Phase 1 끝에 생긴다.

## run — 띄운다

```bash
caffeinate -i nohup ./autopilot.sh > /dev/null 2>&1 &
```

`caffeinate`는 맥 잠자기 방지. 며칠 돌리는 일이다. 사용자가 직접 치게 안내한다 — 세션 안에서 `nohup`으로 띄우면 이 세션 종료와 함께 죽을 수 있다.

`autopilot.sh`는 `.autopilot.pid`로 중복 실행을 막는다. 실측: 사용자가 명령을 두 번 쳐서 루프 2개·세션 2개가 같은 `STATUS.md`에 쓰려 했다. 가드 전 버전이면 `pgrep -f "bash ./autopilot.sh"`로 세고 나중 것을 죽인다.

## status — 본다

```bash
head -3 STATUS.md                          # STATE: / GAME: (또는 프로젝트별 진행 키)
sed -n '/| 단계/,/^$/p' STATUS.md          # 단계 표
tail -c 800 .autopilot.log                 # 마지막 세션의 최종 출력
bmad-loop status --project .               # Phase 2 이후만 의미 있음
```

**`bmad-loop tui`는 Phase 2 전엔 비어 있다.** run이 없으니 당연한데 사용자가 "안 돈다"고 오해한다. 기획 단계에선 `.autopilot.log`와 `git log`가 화면이다.

정상 신호: 루프 밑 자식이 `sleep 300` 아니면 `claude -p` 하나. `git log`에 `chore: Phase X 시도 N회차 시작` → `feat: Phase X 완료` 쌍이 쌓인다. Phase 2에선 `story <key>: implemented and reviewed via bmad-loop` 커밋이 스토리당 하나.

## resume — 죽었을 때

```bash
pgrep -f "bash ./autopilot.sh" || caffeinate -i nohup ./autopilot.sh > /dev/null 2>&1 &
```

그게 전부다. 상태가 파일에 있어서 새 루프가 이어받는다. 단계 중간에 죽었으면 그 단계 처음부터(시도 횟수 +1), Phase 2에서 죽었으면 감시 세션이 `bmad-loop status`를 보고 `resume`한다.

`STATE: BLOCKED_ON_HUMAN`이면 루프가 안 뜬다. `HUMAN_TODO.md` 처리 후 `STATUS.md` 첫 줄을 `STATE: IN_PROGRESS`로 바꾸고 재실행.

## 함정 — 전부 실측

- **`claude -p`는 텍스트 응답으로 턴이 끝나면 프로세스가 종료된다.** 서브에이전트 3개를 background로 띄우고 "기다리겠다"고 텍스트를 내면 그 자리에서 죽는다. 실측: Phase 0 세션 1이 market 보고서만 받고 종료. 프롬프트가 "산출물 파일이 생길 때까지 Bash로 폴링"을 박아 둔 이유. 이 규칙 넣은 뒤 재발 0.
- **세션이 스스로 잠금 파일을 만든다.** 실측: 감시 세션이 중복 실행을 눈치채고 `.autopilot.lock/owner`를 만들었고 스크립트의 `.autopilot.lock` 파일과 충돌. 스크립트는 `.autopilot.pid`를 쓴다. 이름을 바꾸지 마라.
- **에픽 게이트는 정지가 아니라 pause다.** policy `gates = per-epic`면 에픽 끝에 엔진이 멈추고 감시 세션이 sweep·retrospective 후 resume한다. 프롬프트에 명시 안 하면 "run이 안 살아있음 → resume"으로 우회 해석돼 sweep을 건너뛴다.
- **bmad-loop 실행 중에 tool을 업그레이드하지 마라.** `uv tool install --force`가 venv 파일을 바꿔치기해 도는 엔진 python이 깨질 수 있다. 하려면 에픽 게이트에서 `pkill -f autopilot.sh` → 업그레이드 → `bmad-loop init --force-skills` → `resume` → 루프 재기동. 안 올려도 되면 안 올린다.
- **첫 스토리가 도구 설치일 수 있다.** 실측: Flutter·fastlane이 없어서 스토리 1-1이 FVM 설치부터. Xcode·Android SDK처럼 GUI 설치가 필요한 건 setup 때 사람이 미리 깔아야 한다. `xcode-select -p`, `$ANDROID_HOME`으로 실측.
- **감시 세션마다 MCP 인증 경고가 붙는다.** `claude.ai *` 커넥터는 헤드리스에 안 붙는다(grind와 같은 함정). 무해하지만 로그에 매번 찍힌다.
- **실행 중인 `autopilot.sh`를 in-place로 고치지 마라.** bash가 파일을 이어 읽는다. 루프는 매 반복 `cat AUTOPILOT.md`를 새로 읽으므로 **프롬프트 수정은 즉시 반영**되지만 스크립트 수정은 재기동해야 한다.
- **세션 수 ≠ 진행.** 감시 세션은 "이벤트 없음 → 종료"를 5분마다 반복하므로 Phase 2에선 세션 수만 늘고 STATUS는 안 바뀐다. 진행은 `bmad-loop status`의 done 수로 본다.
- **토큰 규모.** 실측: 스토리당 weighted 100~140만 토큰, 스토리 61개. 시작 전에 사용자에게 자릿수를 말한다.

## 완료 기준

`STATUS.md` 첫 줄이 `STATE: DONE`이고, `HUMAN_TODO.md`가 비었거나 사람 작업만 남았고, `docs/decisions/`에 자율 결정 ADR이 있고, `docs/RELEASE_REPORT.md`가 있다.
