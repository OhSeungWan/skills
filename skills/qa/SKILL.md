---
name: qa
description: QA 루프의 우산 스킬 — 분기 4개. 화면 대장을 만들거나 시안 변경을 반영할 때(setup), 사람 QA 직전 시안 대조·플로우 검사로 시트를 미리 채울 때(scan), 팀원의 러프한 QA 보고를 항목으로 쌓을 때(collect), 쌓인 항목을 재현·수정해 배치 PR로 낼 때(fix — 트랙 관례 레포만). 사용자가 "디자인 QA 돌려줘", "대장 갱신해줘", "QA 보고할게", "쌓인 QA 처리해줘"라고 말할 때. /qa <setup|scan|collect|fix>
---

# qa

앱 하나의 QA 루프를 노션 **QA 시트** 한 장 위에서 돈다. 기계가 먼저 채우고(scan), 사람이 쌓고(collect), 수정 결과를 사람이 **존**에서 눈으로 확인해 닫는다.

```
[피그마 시안 · 정답지 파일] ──setup──> 화면 대장 ──scan(시안 대조·플로우 검사)──> 행: 사람 확인 필요 ─사람 검수─┐
                                                                                                                ├─> 시작전 ──수정──> 배포 완료 (존에서 사람 눈)
사람 QA 세션의 러프한 보고 ─────────────collect───────────────────────────────> 행: 시작전 ─────────────────────┘
```

| 분기 | 하는 일 | 규칙 |
| --- | --- | --- |
| `setup` | 화면 대장 생성·갱신 — 피그마 짝짓기 · 셀렉터 유도 · 플로우 분해 · 한 바퀴 자동 검증 | [`references/setup.md`](references/setup.md) |
| `scan` | 대장대로 존을 찍어 시안과 대조(폴리싱) + 플로우 검사(로직), 새로 발견한 결함만 행 생성 | [`references/scan.md`](references/scan.md) · 판정 문안 [`references/judge.md`](references/judge.md) |
| `collect` | 러프한 보고를 항목 단위로 쪼개 시트에 쌓기 | [`references/collect.md`](references/collect.md) |
| `fix` | **옵션 층** — `시작전` 항목을 코드에서 원인 짚어 수정, 배치 PR. 트랙 관례 레포만 | [`references/fix.md`](references/fix.md) |

코어는 setup·scan·collect 셋이고 트랙 없이 돈다. 트랙 관례(`track`·`oracle` 스킬) 레포의 결합 규칙 전부는 [`references/track-integration.md`](references/track-integration.md) — 코어 실행에는 필요 없다.

scan·setup 규칙의 실측 근거는 [`references/rationale.md`](references/rationale.md) — 규칙을 바꿀 때만 읽는다.

## 상태 머신 — 코어 3상태

```
사람 확인 필요 ──사람이 결함 확정──> 시작전 ──수정 후 존에서 사람 눈──> 배포 완료
```

scan이 만든 행은 `사람 확인 필요`로 들어온다 — 오탐 검수 전에 수정 대상이 못 되게 막는 자리다. collect 행은 `시작전`으로 직행한다 — 사람 보고가 곧 확정이다.

**agent가 관측할 수 없는 것만 사람이 찍는다** — 결함이라는 확정(`시작전`)과 눈으로 봤다는 판정(`배포 완료`) 둘뿐이다. 관측으로 알 수 있는 걸 사람에게 시키면 그 칸은 영원히 비어 있다.

세 이름은 fix 층 7상태의 부분집합 그대로다 — fix 도입은 status 옵션 4개(`작성 중`·`진행 중`·`리뷰`·`PR 완료`) 추가만으로 업그레이드된다. 확장 상태 머신과 큐 규칙은 [`references/fix.md`](references/fix.md).

## 프리플라이트 (모든 분기 공통, 맨 먼저)

설치·연결 안내는 문서가 아니라 이 점검이 실행 시점에 한다. 분기가 쓰는 MCP만 점검한다 — setup·scan은 셋 다, collect·fix는 Notion만.

| MCP | 점검 | 없을 때 안내하는 정본 커맨드 |
| --- | --- | --- |
| Playwright | 도구 목록에 `mcp__*playwright*` | 플러그인 동봉(`plugin.json`의 `mcpServers`)이라 설치는 끝 — 세션 재시작. MCP는 세션 시작 때만 붙는다 |
| Figma | 도구 있음 + 읽기 호출 1회 성공 | 도구 없음: `/plugin install figma@claude-plugins-official` 후 세션 재시작. 인증 실패: `/mcp`에서 Figma를 골라 `Authenticate` |
| Notion | 도구 있음 + 읽기 호출 1회 성공 | 도구 없음: `/plugin install notion@claude-plugins-official` 후 세션 재시작. 인증 실패: `/mcp`에서 Notion을 골라 `Authenticate` |

읽기 호출 1회는 `.qa/config.yaml`이 아직 없는 레포(첫 바퀴)에서만 한다 — config가 있으면 도구 유무만 보고, 인증 오류는 실제 호출에서 잡혀도 같은 표로 안내한다. 데스크톱 앱은 `/mcp` 대신 Settings → Connectors, 같은 흐름이다.

하나라도 빠지면 해당 커맨드를 안내하고 **멈춘다**. 분기 몫 전부가 확인됐을 때만 값 결정으로 넘어간다 — 통과는 조용히 지나간다.

## 값 결정 (모든 분기 공통, 프리플라이트 다음)

**모든 값의 1순위는 대상 레포 `.qa/config.yaml`이다.** 필수 키는 둘뿐 — `zone:`과 `figma:`(file_key·page_id). 나머지는 옵션이거나 실행 중 얻어 config에 기록한다. 트랙 참조(통합 PR·티켓 표·스펙 이슈)는 후순위 옵션 — [`references/track-integration.md`](references/track-integration.md).

| 값 | 결정 방법 |
| --- | --- |
| 존 | config `zone:`. 렌더되는 URL이면 전부 존이다 — localhost dev 서버·preview 포함. 없으면 물어 기록한다 |
| 시안 정본 | config `figma:`. 없으면 사람에게 물어 기록한다 |
| QA 시트 | config의 시트 URL > 인자로 받은 노션 DB URL > 워크스페이스 검색 후 **후보를 제시하고 확인받는다** |
| 시트 생성 | 어느 분기든 시트가 없으면 만든다. 부모 페이지 위치는 추론하지 않고 URL을 묻는다 — 노션에 잘못 만든 DB는 사람 손으로만 지운다. 아래 스키마로 생성하고 URL을 config에 기록해 다음부터 안 묻는다 |

옵션 키: 시트 URL · `storage_state` 경로 · 뷰포트 · 동적 세그먼트 식별자 · 진입/종결 상태 이름 · `oracle:` 블록(트랙 층 — `/oracle` 스킬이 같은 자리를 읽는다).

**scan·setup의 실행 위치는 대상 레포다.** `.qa/`·`.gitignore`·스크린샷 상대 경로가 전부 거기 기준이다.

## 시트 스키마

| 프로퍼티 | 타입 | 채우는 주체 |
| --- | --- | --- |
| (title) | title | agent — 증상 요약 한 줄. 새로 만드는 시트는 이름을 `증상`으로, 기존 시트는 이름이 무엇이든 그대로 두고 거기에 증상을 쓴다 |
| 테스트 번호 | number | agent — 시트 내 최대 + 1 |
| 재현순서 | text | 사람 (scan 행은 agent가 대장 스텝을 사람 문장으로) |
| 테스트한 사람 | person | 사람 |
| 성질 | select `폴리싱` / `로직` / `미판정` | agent |
| 해결 여부 | status — 코어 3상태 (fix 도입 시 +4, [`references/fix.md`](references/fix.md)) | agent (`시작전`·`배포 완료`는 사람) |
| PR | url | agent |
| 비고 | text | agent — `사람 확인 필요`로 보낼 때 사유, scan 행은 `qa-key:`와 근거 |

기존 시트를 만나면 **없는 프로퍼티와 없는 status 옵션만 추가한다**(`notion-update-data-source`). status 옵션 추가는 기존 행의 값을 건드리지 않는다. status 그룹은 `사람 확인 필요`·`시작전`을 to-do, `배포 완료`를 complete에 둔다 — 사람 눈을 통과하기 전은 끝난 게 아니다.

## 용어 (scan·setup)

| 용어 | 뜻 |
| --- | --- |
| 존 | scan·setup이 실물을 찍는 렌더 가능한 URL 환경 — 렌더되는 URL이면 전부. config `zone:` 한 줄이 요건의 전부다 |
| 대장 | 대상 레포 `.qa/ledger.yaml`. 화면 > 캡처 > 섹션 계층으로 도달 경로·시안 노드·셀렉터를 적은 사람 검수 자산. 앱 단위 — 어느 작업 단위보다 오래 산다. 스키마는 [`references/setup.md`](references/setup.md) |
| 실물 / 시안 | 존 스크린샷 / 피그마 노드 이미지 |
| 갈래 | 판정이 고르는 결함 종류 여덟: 여백·크기·컬러·에셋·정렬·문구·누락·잉여 |
| 지문 키 | 비주얼은 `<화면 slug>[-<스텝>]/<섹션 slug>/<갈래>`, 플로우는 `<화면 slug>/<정답지 항목 ID>`. 시트 `비고`에 `qa-key: …`로 박혀 중복을 거른다 |
| 정답지 파일 | 대상 레포 `.qa/flows/<프로젝트 slug>.yaml` — 플로우 정답지의 물화이자 setup·scan의 유일한 읽기 심. 항목은 4칸(id·문장·상태·출처), `확정`만 분해된다([ADR-0005](../../.agents/adr/0005-flow-answer-key-is-single-human-confirmed-source.md)) |
| 플로우 | 대장 화면 레벨 `flows:`의 원자 검사 — 정답지 파일의 `확정` 항목 하나를 조작 후 URL·문구·속성 단언으로 옮긴 것 |
| 짝짓기 | 실물 캡처와 시안 프레임이 같은 화면인지 확인하는 일. 실행 게이트(`match_text`)와 판정의 `같은 화면인가` 두 겹 |
| 미커버 / 시안 대기 | 못 찍은 화면(대장을 손봐라) / `stale`로 건너뛴 섹션(시안을 기다려라) |

## 분기 판별

**인자 필수** — `/qa <setup|scan|collect|fix>`. 인자가 없으면 아무것도 실행하지 않고 상태만 찍는다: 시트 상태 분포 · 마지막 scan 실행 시각과 요약(`.qa/runs/`) · 대장 신선도(`figma.version`) — 그리고 어느 분기로 보이는지 한 줄 제안한다. 네 분기 모두 외부에 보이는 것(노션 행·브랜치·PR·시트)을 만들므로 감지 결과는 제안까지만 쓴다.

## agent가 하지 않는 것

기계 발견의 범위는 scan의 시안 대조 폴리싱과 **정답지 파일 `확정` 항목에서 분해된 플로우 검사**까지다. 정답지에 없는 기대값을 agent가 추론해 검사하지 않는다 — 그건 제품 결정이다. 나머지 로직·UX 결함 발견과 판단은 사람 몫이고, 그 자리를 어설픈 자동화가 대신하면 품질이 내려간다. agent가 앱을 띄워 재현하는 일은 fix에서 정적 추적이 실패했을 때의 마지막 수단뿐이다 — 게이트와 예외는 [`references/fix.md`](references/fix.md).
