# AUTOPILOT — 모바일 게임 1종 무인 출시 프롬프트

> 이 파일 전체를 Claude Code 세션(bypass permissions 모드)에 붙여넣는다.
> 사전 조건: `bmad-loop init --project . --cli claude` 실행 후 `claude`를 한 번 재시작해 hooks 승인 완료 상태.

---

## 임무

App Store와 Google Play에 실제 출시하는 모바일 게임 **3종**을 순차로 처음부터 끝까지 만든다. 아래 Phase 0~4를 게임 하나에 대해 완주하고, "게임 순차 진행 규칙"에 따라 다음 게임으로 넘어간다.
너는 프로젝트 오너이자 오케스트레이터다. 사람은 개입하지 않는다. 질문하지 말고 결정하라.
결정이 필요한 모든 지점에서 스스로 판단하고, 판단 근거를 `docs/decisions/`에 ADR 한 파일로 남긴 뒤 계속 진행한다.

**사람이 개입하는 유일한 예외**: 계정 생성·결제·서명 자격증명·법적 동의 등 사람의 신원이나 돈이 필요한 행위.
이런 항목은 `HUMAN_TODO.md`에 "정확히 무엇을, 어디서, 어떻게, 결과물을 어디에 두는지"까지 적고, 그 항목에 의존하지 않는 다른 일을 계속한다. 절대 기다리며 멈추지 않는다. 전부 막혔을 때만 `HUMAN_TODO.md`를 최종 정리하고 종료한다.

## 재개 규칙 (컨텍스트 보호)

이 프롬프트는 한 세션에서 끝나지 않는다. 바깥의 `autopilot.sh`가 세션을 반복해서 띄운다.

- **시작 시 항상** `STATUS.md`를 먼저 읽는다. 있으면 거기 적힌 "다음 할 일"부터 시작하고, 이미 완료된 단계는 건너뛴다. 없으면 Phase 0부터.
- 단계 하나(Phase 내 번호 항목 하나)를 끝낼 때마다 `STATUS.md`에 완료 표시 + "다음 할 일" 한 줄 갱신 + git commit. 이 갱신이 체크포인트다.
- **세션 하나는 큰 단계 하나만** 수행하고 종료한다 (예: Phase 1의 PRD 작성 하나, Phase 2의 `bmad-loop run` 감시 하나). 끝나면 "다음 세션에서 계속"이라고 STATUS.md에 적고 세션을 끝낸다. 더 할 수 있어도 이어서 하지 않는다.
- 결정 근거는 대화가 아니라 파일(`docs/decisions/`, planning-artifacts)에만 의존한다. 이전 세션의 대화 내용을 기억한다고 가정하지 않는다.
- **비대화형(`claude -p`) 세션이므로 텍스트 응답으로 턴을 끝내는 순간 프로세스가 종료된다.** 서브에이전트나 백그라운드 작업이 남아 있는 동안 "기다리겠다"는 텍스트로 턴을 끝내지 않는다. 대신 산출물 파일이 생길 때까지 Bash로 폴링한다 (예: `until [ -f 경로 ]; do sleep 30; done`, timeout 넉넉히). 완료 알림이 오면 이어서 진행한다. 세션을 끝내는 텍스트는 STATUS.md 갱신·commit을 마친 뒤에만 낸다.
- 이미 존재하는 산출물(연구 보고서, 문서, 코드)은 재생성하지 않고 읽어서 이어간다. 재시도는 빠진 부분만 채운다.
- 긴 출력(빌드 로그, 시뮬레이터 로그, 테스트 결과)은 파일로 리다이렉트하고 `tail`·`grep`으로 결정적인 줄만 읽는다.
- Phase 2 감시: `bmad-loop status`를 확인해 처리할 이벤트가 없으면 아무것도 하지 말고 세션을 종료한다. 재기동은 바깥 루프가 한다. `/loop`는 쓰지 않는다.
- 단계를 시작할 때 `STATUS.md`의 해당 단계 "시도 횟수"를 1 올리고 commit한다. 3회째 시도에서도 완료하지 못하면 `STATE: BLOCKED_ON_HUMAN`으로 바꾸고 실패 원인을 `HUMAN_TODO.md`에 적은 뒤 종료한다.
- 모든 일이 끝났거나 사람 작업만 남았으면 `STATUS.md` 첫 줄에 `STATE: DONE` 또는 `STATE: BLOCKED_ON_HUMAN`을 적는다. 바깥 루프는 이 줄을 보고 멈춘다.

## 게임 순차 진행 규칙 (3종)

BMAD 산출물 경로(`_bmad-output/`)와 `sprint-status.yaml`은 하나뿐이다. 따라서 **동시에 진행 중인 게임은 항상 1개**다.

레포 구조:
```
apps/<game-slug>/                 # 게임별 앱 프로젝트 (게임마다 하나)
packages/<name>/                  # 게임 간 공통 코드: ads, iap, storage, ui-kit, fastlane 레인
_bmad-output/                     # 현재 진행 중인 게임의 산출물만
_bmad-output/archive/<game-slug>/ # 출시 끝난 게임의 planning/implementation 산출물
docs/games/<game-slug>/           # 게임별 RELEASE_REPORT, 스토어 메타데이터, 개인정보처리방침
```

`STATUS.md`는 첫 줄 `STATE:` 아래에 `GAME: <n>/3 <game-slug>`를 둔다. 세션 시작 시 이 줄로 어느 게임의 어느 단계인지 판단한다.

게임 하나가 Phase 4까지 끝났을 때 (심사 제출 준비 완료 또는 사람 작업만 남음):
1. `docs/games/<game-slug>/RELEASE_REPORT.md` 작성.
2. `_bmad-output/planning-artifacts`, `implementation-artifacts`, `specs`를 `_bmad-output/archive/<game-slug>/`로 이동. `bmad-loop archive`로 실행 기록 정리.
3. `bmad-retrospective` 실행 → 교훈을 AGENTS.md와 `docs/decisions/`에 반영.
4. 게임 간 중복 코드가 있으면 `packages/`로 추출하는 스토리를 다음 게임의 첫 에픽에 포함시킨다 (별도 리팩터링 단계를 만들지 않는다).
5. `STATUS.md`의 `GAME:`을 다음 번호로 올리고 commit. 다음 세션은 Phase 0부터.

게임 2·3의 Phase 0: 이전 게임의 `game-selection.md`를 읽고 **다른 장르**를 고른다. 시장 조사는 갱신만 하고 처음부터 다시 하지 않는다 (competitive·technical 서브에이전트만 새로 실행, market은 이전 결과 재사용).
게임 2·3의 Phase 1~4: `packages/`에 이미 있는 광고·IAP·저장·fastlane은 PRD에서 "재사용"으로 표시하고 스토리를 만들지 않는다.

`HUMAN_TODO.md`는 게임별 섹션으로 나눈다. 계정·서명·AdMob 계정은 게임 1에서 한 번만 필요하고, 게임 2·3은 콘솔에서 앱 생성·IAP 상품 등록·심사 제출만 남는다.

**`STATE: DONE`은 3개 모두 끝났을 때만** 적는다. 게임 1이 사람 작업(계정·자격증명)에 막혀도 게임 2·3의 Phase 0~3은 진행할 수 있으므로, `BLOCKED_ON_HUMAN`은 3개 모두 사람 작업 외에 할 일이 없을 때만 적는다.

## 작업 원칙

- 모든 단계는 BMAD 스킬로 수행한다 (`/bmad-help`로 현재 상태에 맞는 다음 스킬을 확인).
- 각 BMAD 스킬이 사람에게 묻는 질문은 네가 사용자 역할로 답한다. 기본값·권장값·앞선 문서와 일치하는 값을 고른다.
- 독립적인 조사·검토는 서브에이전트로 병렬 실행한다. 구현은 bmad-loop에 위임한다.
- 진행 상황은 `STATUS.md`에 단계별로 기록한다 (완료/진행중/막힘, 마지막 갱신 시각).
- 매 단계 종료 시 git commit. 브랜치는 `main` 하나만 쓴다 (bmad-loop이 스토리별 워크트리를 관리).
- 완성도 기준(아래 "출시 품질 기준")을 만족하지 못하면 다음 단계로 넘어가지 않는다.

---

## Phase 0 — 조사 및 게임 선정

`bmad-deep-recon`을 서브에이전트 3개로 병렬 실행:

1. `market` — 2024~2026 양대 스토어 캐주얼 퍼즐 카테고리. 후보군: 수도쿠, 넘버 퍼즐(2048류), 블록 퍼즐(1010!/Block Blast류), 노노그램, 미로, 벽돌깨기, 지뢰찾기, 워드서치, 솔리테어. 각 후보의 다운로드 규모·수익 모델·경쟁 강도·신규 진입 앱의 생존율.
2. `competitive` — 후보별 상위 5개 앱의 리뷰 분석: 사용자가 반복 불만 제기하는 것(광고 빈도, 난이도 곡선, UI)과 칭찬하는 것. 우리가 차별화할 지점.
3. `technical` — 1인 개발·서버 없음·오프라인 완전 동작·양대 스토어 단일 코드베이스 조건에서의 스택 비교 (Flutter+Flame, Godot, React Native+Expo, Unity). 광고 SDK(AdMob), IAP, 스토어 자동 배포(fastlane) 성숙도 포함.

선정 기준 (가중치 순):
- 콘텐츠를 절차적으로 무한 생성 가능 (레벨 수작업 제작 불필요)
- 아트 요구가 낮고 미니멀 디자인으로도 상품성이 나옴
- 검증된 수익 모델: 전면·보상형 광고 + "광고 제거" IAP 단일 상품
- 세션 길이 짧고 재방문 유도 장치(일일 도전, 연속 기록)가 자연스러움
- 진입 경쟁이 극단적으로 포화된 것(수도쿠·2048 기본형)은 명확한 차별화 없이는 감점

결과: `_bmad-output/planning-artifacts/research/game-selection.md`에 1종 확정 + 차별화 포인트 3개 + 스택 확정. 이후 모든 단계는 이 문서를 최상위 권위로 삼는다.

## Phase 1 — 기획

순서대로 실행, 각 산출물은 다음 스킬의 입력이 된다:

1. `bmad-product-brief` — 선정 문서 기반. 타깃, 핵심 루프, 수익 모델, 성공 지표(D1 리텐션 35%+, 크래시 프리 99.5%+, 평점 4.3+).
2. `bmad-prd` — 기능 범위를 **v1.0에 필요한 최소**로 고정. 반드시 포함: 핵심 게임플레이, 절차적 레벨 생성기(난이도 5단계), 일일 도전, 통계/연속기록, 설정(사운드·햅틱·테마), 온보딩 튜토리얼, 광고(전면 광고는 N판마다·보상형은 힌트/되돌리기), "광고 제거" IAP + 구매 복원, 광고 동의(UMP/ATT), 다국어(en/ko/ja), 개인정보처리방침 링크. 제외: 계정, 서버, 리더보드, 소셜.
3. `bmad-ux` — DESIGN.md/EXPERIENCE.md. 미니멀·고대비·다크모드 기본 지원. 한 손 조작. 광고 노출 시점을 UX 흐름에 명시.
4. `bmad-architecture` — Phase 0에서 확정한 스택. 오프라인 우선, 로컬 저장, 광고/IAP는 인터페이스 뒤에 격리(테스트 시 가짜 구현), 레벨 생성기는 순수 함수로 유닛 테스트 가능하게. fastlane 기반 양대 스토어 배포 파이프라인을 아키텍처 범위에 포함.
5. `bmad-create-epics-and-stories` — 스토리는 각각 1세션(약 1~2시간)에 끝나는 크기. 마지막 에픽은 "스토어 출시 준비"(아이콘·스크린샷·메타데이터·개인정보처리방침·fastlane 레인).
6. `bmad-review`로 PRD·아키텍처·스토리를 검토하고 CRITICAL/HIGH 지적은 직접 수정.
7. `bmad-project-context` — AGENTS.md에 빌드/테스트/린트 명령, 규약, 함정을 기록. bmad-loop이 띄우는 세션이 이 파일에 의존한다.
8. `bmad-sprint-planning` — PASS가 나올 때까지 앞 단계를 보완. CONCERNS면 원인을 고치고 재실행.

## Phase 2 — 구현 (bmad-loop)

```bash
bmad-loop validate --project .      # 실패 항목은 고치고 재실행, 통과할 때까지
bmad-loop run --project .           # 전 스토리 무인 실행
```

- 실행 중에는 `/loop 10m` 으로 `bmad-loop status --project .`를 폴링한다. 폴링 결과에 따라:
  - `paused` + CRITICAL 에스컬레이션: 사람 대신 네가 해결한다. 에스컬레이션 내용을 읽고 PRD/아키텍처/스펙을 근거로 결정, ADR 기록, 해당 스토리 스펙을 수정한 뒤 `bmad-loop resume`. (`bmad-loop-resolve`는 대화형이므로 쓰지 않는다.)
  - `awaiting-operator`: 외부 행위가 필요한 스토리. `HUMAN_TODO.md`에 항목 추가. 사람이 처리한 흔적(파일·환경변수)이 확인되면 `bmad-loop confirm`. 확인 안 되면 그 스토리를 건너뛰고 나머지를 계속 진행 (`--story`로 개별 실행).
  - 실패 반복 3회 이상인 스토리: `bmad-correct-course`로 스토리를 분할·재정의하고 재실행.
  - 에픽 게이트로 paused (policy `gates = per-epic`): `bmad-loop sweep --project . --min-severity high`(high/critical만 — low/medium 유예작업은 Phase 2 끝 전체 sweep으로 미룬다. 실측: 전부 돌리면 게이트가 에픽 구현보다 오래 걸린다) → `bmad-loop decisions --project . --list`로 남은 결정을 보고 PRD·아키텍처에 맞는 선택지(기본은 recommended)를 골라 `_bmad-output/implementation-artifacts/deferred-work.md` 해당 항목에 `decision: <날짜> <선택 라벨> — <근거>` 줄로 직접 기록(`bmad-loop decisions`는 대화형이라 쓰지 않는다) → `bmad-retrospective` → `bmad-loop resume`. 사람 승인을 기다리지 않는다.
  - `done`: 다음 단계.
  - run이 살아있지 않음(stopped/orphaned, tmux 세션 없음) 또는 `bmad-loop list`에 미완 run이 있음: `bmad-loop resume`. run 자체가 없는데 sprint-status에 미완 스토리가 남았으면 `bmad-loop run`.
- 에픽 하나가 끝날 때마다 `bmad-loop sweep --project .`으로 유예 작업 정리, `bmad-retrospective`로 교훈을 AGENTS.md에 반영.
- 전 스토리 완료 후 `bmad-loop sweep --project . --repeat`로 남은 유예작업을 한 번에 정리한다 (이미 해결됐거나 중복인 항목은 triage가 걸러낸다).
- 그다음 `bmad-code-review`(전체 diff)와 `bmad-qa-generate-e2e-tests`를 실행하고 지적 사항은 스토리로 추가해 다시 `bmad-loop run`.

## Phase 3 — 검증

시뮬레이터/에뮬레이터에서 실제로 실행하고 확인한다. 로그만 보고 통과 처리하지 않는다.

- 신규 설치 → 온보딩 → 10판 플레이 → 앱 종료 → 재실행 시 진행 상태 복원
- 광고: 테스트 광고 ID로 전면·보상형 노출 시점 확인, 동의 폼 노출 확인
- IAP: 샌드박스에서 구매·복원 동작, 구매 후 광고 완전 차단 확인
- 비행기 모드에서 전 기능 동작
- 저사양 기기 프로파일에서 60fps, 콜드 스타트 2초 이내
- 레벨 생성기: 1만 회 생성 시 해가 유일하고 난이도 지표가 단조 증가함을 테스트로 증명
- 3개 언어 UI 깨짐 없음, 시스템 폰트 확대 200%에서 레이아웃 유지
- 실기기 스크린샷을 스토어 규격(6.7"/6.5"/5.5" iPhone, iPad, Android 폰/태블릿)으로 자동 생성 (fastlane snapshot/screengrab)

하나라도 실패하면 스토리로 등록해 Phase 2로 돌아간다.

## Phase 4 — 출시

네가 직접 할 수 있는 것은 전부 한다:
- 앱 아이콘·피처 그래픽·스크린샷 생성 및 규격 검증
- 스토어 메타데이터 3개 언어 (제목, 부제, 설명, 키워드, 출시 노트)
- 개인정보처리방침·이용약관 페이지를 `docs/` 아래 정적 HTML로 작성, GitHub Pages로 호스팅 설정
- App Privacy(iOS)·Data safety(Android) 답변서, 연령 등급 설문 답변서, 광고 ID 사용 선언
- fastlane `Fastfile`·`Appfile`·`Matchfile` 작성, `beta`·`release` 레인, GitHub Actions 워크플로
- 버전·빌드번호 정책, 릴리즈 노트 자동 생성

사람만 할 수 있는 것은 `HUMAN_TODO.md`에 체크리스트로 남긴다 (각 항목에 URL, 예상 비용, 소요 시간, 결과물을 둘 경로·환경변수명 명시):
- Apple Developer Program 가입 (USD 99/년), App Store Connect API 키 발급 → `fastlane/AuthKey_*.p8`
- Google Play Console 등록 (USD 25), 서비스 계정 JSON 발급 → `fastlane/play-service-account.json`
- 서명: iOS 인증서(match 저장소 초기화), Android 업로드 키스토어 → `android/keystore.properties`
- AdMob 계정 생성, 앱 등록, 광고 단위 ID 발급 → `.env`
- 양 스토어에서 IAP 상품(`remove_ads`) 등록 및 가격 설정
- 스토어 콘솔에서 앱 최초 생성 (번들 ID·패키지명은 네가 정해 문서에 기재)
- 최종 "심사 제출" 버튼 클릭 (법적 동의 포함)

자격증명이 위 경로에 나타나면 즉시 감지해 `fastlane beta` → 내부 테스트 트랙 업로드 → 이상 없으면 `fastlane release`로 심사 제출 준비까지 진행한다.
심사 거절이 `HUMAN_TODO.md`에 기록되어 돌아오면 거절 사유를 스토리로 만들어 Phase 2~4를 반복한다.

## 출시 품질 기준 (모두 충족해야 "완료")

- 플레이스홀더 아트·텍스트·TODO 주석 0개
- 유닛 테스트: 레벨 생성기·점수·저장/복원 로직 커버리지 90% 이상, 전부 통과
- 린트·타입체크·포맷 경고 0개
- 크래시 없이 연속 30분 플레이 (자동화 스크립트로 증명)
- 앱 크기 50MB 이하
- 접근성: 최소 터치 영역 44pt, 색상만으로 정보 전달하는 UI 없음, 스크린리더 레이블
- 스토어 심사 가이드라인 셀프 체크리스트 통과 (Apple 4.2 최소 기능, 5.1.1 개인정보, Google 광고 정책·데이터 안전)

## 종료 시 산출물

- 실행 가능한 앱: `fastlane beta`로 양 스토어 내부 테스트 트랙에 올라간 빌드 (자격증명 있는 경우)
- `STATUS.md`: 단계별 완료 내역, 남은 사람 작업, 예상 출시 일정
- `HUMAN_TODO.md`: 사람이 할 일 체크리스트 (비어 있으면 출시 완료)
- `docs/decisions/`: 모든 자율 결정의 ADR
- `docs/RELEASE_REPORT.md`: 게임 소개, 차별화 포인트, 수익 모델, 검증 결과, 알려진 제한

시작하라. 첫 행동은 Phase 0 서브에이전트 3개 병렬 실행이다.
