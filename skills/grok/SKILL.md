---
name: grok
description: AI 산출물(diff·스펙·임의 자료)을 사람이 진짜로 이해하게 만드는 인지부채 해소 도구. /grok <대상>으로 호출.
disable-model-invocation: true
---

# grok

## 목적

AI가 만든 것(코드 변경·설계 문서·임의 자료)을, 그것을 승인·사용하는 사람이 *진짜로* 이해하도록 돕는다.
(인지부채 해소 — 검증이 아니라 이해를 위한 참여)

## 분기

하나의 파이프라인이 대상 종류에 따라 세 분기로 나뉜다. 1단계에서 판별한다.

| | **code** | **spec** | **quiz** |
|---|---|---|---|
| 대상 | diff / 커밋 범위 / 브랜치 | 스펙·설계 문서 (승인 전) | 그 외 임의 자료 |
| 고유 섹션 | Code 워크스루 | 핵심 결정·가정·리스크 + 열린 질문 | (퀴즈만) |
| 전용 레퍼런스 | `references/literate-code.md` | `references/surfacing-decisions.md` | — |
| 그림 | 핵심 개념 1개 이상 | 조건부 (메커니즘 체감 필요 시만) | 없음 |
| 출력 | Notion 하이브리드 페이지 | 터미널 인라인 (Notion 영구본은 옵션) | 자기완결 HTML + 터미널 요약 |
| 자기점검 게이트 | **하드** — 산출물이 외부 영구 저장소로 나가므로, 통과 전 업로드 금지 | 소프트 거버너 | 소프트 거버너 |
| 퀴즈 프로파일 | 기존형 | 제안형 | 분류해서 결정 |

실행 중에는 **해당 분기의 전용 레퍼런스만 읽는다** — 다른 분기 규칙(예: spec의 proposed 표시)을 code 실행에 섞지 않는다.

## 프로세스 (순서대로)

1. **대상 해석 + 분기 판별** — 첫 인자가 `code`/`spec`/`quiz`면 그 분기로 강제. 아니면 대상으로 판별:
   - git 리비전(`<base>...<head>`)·diff·인자 없음(기본 `git diff main...HEAD`) → **code**. 빈 diff / git 저장소 아님 → 알리고 중단.
   - 스펙/설계 문서 경로, 또는 `docs/superpowers/specs/`의 최신 문서 지목 → **spec**. 스펙이 아니거나 비었으면 알리고 중단.
   - 그 외(기술 문서·ADR·PRD 파일, 디렉터리/코드 모듈, 주제/붙여넣은 텍스트) → **quiz**. 디렉터리는 그 경계를 기본 범위로 하되 모듈이 여러 디렉터리에 걸치면 사용자에게 확인. 실질 내용이 없으면 알리고 중단.
   - 애매하면 후보를 제시하고 사용자에게 묻는다.

2. **Notion 사전 확인** (code 분기만) — 문서 저작을 시작하기 전에 가벼운 호출(`notion-search` 등)로 Notion MCP 연결을 확인한다. 안 되면 다 만든 뒤가 아니라 맨 앞에서 사용자에게 알린다. spec/quiz 분기는 Notion 없이도 완결되므로 건너뛴다.

3. **맥락 파악** — 대상과 그것이 참조하는 소스를 읽어 의도·핵심 개념을 이해한다. 분기별 추가:
   - **spec**: 현재 세션에 이 스펙을 만든 브레인스토밍 대화(버려진 대안, 트레이드오프)가 있으면 반드시 맥락에 포함 — 스펙 본문에는 최종 선택만 남는 경우가 많다.
   - **quiz**: 자료를 **제안형**(스펙·ADR·PRD — 실행 전) / **기존형**(코드·시스템·아티클 — 이미 실재)으로 분류. 애매하면 한 번 확인.

4. **설계** — 다음을 정한다: 핵심 멘탈모델 한 문장 / (그림 분기면) 그림으로 만들 개념 / 분기 고유 섹션의 내용 / 퀴즈 5문항.
   - 공통: `references/intuition-first.md`, `references/writing-quizzes.md`
   - code: `references/literate-code.md`로 Code 섹션 서술 순서 결정
   - spec: `references/surfacing-decisions.md`로 load-bearing 결정을 네 필드로 전개, grounding 규칙 적용, 열린 질문 수집. 퀴즈에 동의/가정 확인 ≥1문항.

   **문서 언어(반드시): 생성 문서의 산문·퀴즈 문항·답변은 전부 한글. 코드 발췌·식별자·확립된 기술 용어(API명·함수명·라이브러리명)는 원문 유지, 번역 금지.**

5. **그림/렌더 생성** —
   - code/spec: `assets/figure-template.html`을 복제해 채운다(`references/interactive-figures.md`). spec은 체감할 메커니즘이 있을 때만 만들고, 그림 안에 **proposed(미구현) 시뮬레이션**임을 표시.
   - quiz: `assets/quiz-template.html`을 복제해 퀴즈 HTML을 만든다(질문 → 선택지 → 정답+근거를 접힌 `<details>`에). 저장 위치는 지정 없으면 현재 디렉터리, 대상·날짜 기반 파일명.
   - 생성한 모든 HTML은 `scripts/check-self-contained.sh <file>` 통과 확인(자기완결·≤200KiB).

6. **자기점검 (Litt 규칙)** — `references/writing-quizzes.md`§"Litt 규칙"대로 **새 서브에이전트**에게 렌더링된 문서 텍스트만 건네 퀴즈 5문항을 콜드로 풀게 한다. 틀린 문항의 처리(문서 보강 / 문항 재조준 / 사용자 보고)도 그 문서를 따른다. 게이트 강도는 분기 표 참조 — code만 하드.

7. **출력** —
   - **code**: `references/notion-assembly.md`대로 Notion 하이브리드 페이지 생성(TOC + Background/Intuition/Code + `<embed>` 그림 + 중첩 토글 퀴즈). 이전 시도에서 이미 업로드했고 6단계에서 보강했다면 새로 만들지 말고 `notion-update-page`로 영향 블록만 갱신.
   - **spec**: 터미널 인라인 출력(멘탈모델 + 핵심 결정·리스크 + 열린 질문) — **이 인라인 출력 자체가 승인 게이트다.** 그 후 "영구본 남길까요?" 물어 "예"면 `references/notion-assembly.md`대로 페이지 생성(`type=spec`, spec→구현 relation은 빈 채로). Notion 불가면 인라인만으로 목적 달성, 우아하게 종료.
   - **quiz**: HTML 파일을 열고(가능하면 CLI로), 터미널에 요약 인라인 출력: 대상 + 프로파일 + 5개 질문 줄기(정답 제외) + 파일 경로.

8. **보고** — 분기 산출물 위치(Notion URL / 파일 경로)와 핵심 멘탈모델 포함 3~5줄 요약.

## 전역 규칙

- git 소스에 산출물을 커밋하지 않는다(저장소 역할은 Notion 또는 사용자 보관).
- 거대 대상: 조용한 절삭 금지 — 핵심 우선 서술 + 생략분 명시.
- 다이어그램은 HTML/CSS/SVG, ASCII 아트 금지. 산문은 Kleppmann 명료체(`references/intuition-first.md`).
- Notion 오류 처리(parent 오류 폴백, 첨부 1시간 만료 재업로드)는 `references/notion-assembly.md`가 단일 출처.
