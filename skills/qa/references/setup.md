# setup — 화면 대장 만들기와 갱신하기

`scan`이 읽는 자산을 짓는다. AI가 초안을 다 채우고 한 바퀴 돌려 자동 검증하며, 사람은 **걸러진 줄만** 본다. 전량 검수는 새 병목이다.

돌리는 때: 대장이 없을 때 · `figma.version` 불일치 · `scan`이 짝짓기 실패·미커버를 보고했을 때 · `scan`이 화면을 `unpaired`로 강등했을 때.

## 사는 곳

대상 레포 `.qa/`. 커밋되는 것은 `.gitignore` 두 줄뿐 — `.qa/`와 `.playwright-mcp/`(MCP가 cwd에 떨구는 부산물).

**워크트리가 여럿이면 `.qa/` 정본은 하나다.** gitignore라 워크트리마다 사본이 생기고, 어느 한쪽에서 setup/scan 이 돌면 그 순간 갈라진다 — 대장은 사람 검수 자산이라 검수가 사본 하나에 갇힌다(2026-08-27 실측: 같은 앱 워크트리 3곳에 사본). 리포 밖 한 곳(공유 스토어 류)에 두고 각 워크트리에서 `.qa/`를 심링크하거나, scan·setup 을 도는 워크트리를 하나로 고정한다. `cache/`·`runs/`도 같이 공유해도 안전하다 — run 이름이 ISO 시각이라 안 충돌하고 캐시는 겹칠수록 이득이다.

```
.qa/
  ledger.yaml            # 대장 — 앱 단위. 어느 작업 단위보다 오래 산다
  config.yaml            # 필수: 존 URL·피그마 기본값. 옵션: 시트 URL·세션 경로·뷰포트·동적 식별자·진입/종결 상태·오라클 좌표(트랙 층)
  judge-prompt.md        # 판정 문안 사본. scan 이 references/judge.md 에서 매번 덮어쓴다 — 손대지 않는다
  cache/<file_key>/<figma.version>/<node_id>.png
  runs/<run>.yaml        # scan 실행 기록 (사람이 읽는 것)
  runs/<run>/            # 섹션 스크린샷 <화면>__<섹션>.png + 행 생성 작업 파일(pairs·rows·pages·upload-ids)
```

세션 파일(`storageState`)은 여기 두지 않는다 — 대상 레포의 시각 회귀 하네스가 쓰는 자리가 있으면 그 경로를 `config.yaml` `storage_state`로 가리켜 파일 하나로 양쪽이 돈다. MCP 에는 `.claude/settings.local.json` 의 `env` 블록이 경로를 준다(아래 「세션 파일」).

대장과 설정을 가르는 이유는 수명이다 — 대장은 앱 단위, 설정은 존마다. 동적 세그먼트 식별자는 환경변수가 아니라 `config.yaml`에 직접 적는다. 포맷은 YAML — 주석이 사람 검수 자산의 본체다("여기서 완료를 누르면 실제 주문이 나간다").

## 대장 스키마

계층은 **화면 > 캡처 > 섹션**. 위저드는 URL 하나에 화면 여러 장이고 스텝마다 시안 프레임이 따로 있으므로 `frame_id`와 `sections[]`는 캡처에 붙는다.

```yaml
version: 1

figma:
  version: <ISO 8601>         # 파일 lastModified. 노드별 수정시각이 없어 갱신 감지의 유일한 축
  source: <피그마 URL 출처>    # config `figma:` 값을 캐낸 자리 기록. 트랙 레포는 스펙 이슈(track-integration.md)

screens:
  - slug: <화면 slug>          # 지문 키 첫 조각. 한 번 정하면 바꾸지 않는다
    name: <화면 이름>
    path: /<라우트>            # config 키는 {중괄호}로 참조
    status: ready              # ready | unreached | blocked | unpaired
    confidence: confirmed      # confirmed | guessed
    requires: []               # config 키 목록. 하나라도 비면 스킵·미커버
    forbidden: []              # 어떤 경우에도 clickText 하지 않는 문구
    captures:
      - step: ""               # 스텝 없는 화면은 빈 문자열
        captured: true         # false면 조작만 하고 찍지 않는다(경유 스텝)
        arrival_text: <이 화면에만 보이는 문구>
        match_text: []         # 짝짓기용 고유 문자열 ≤5. 파생값
        before: []             # 도달 조작
        figma:
          page_id: <page_id>
          frame_id: <frame_id>      # 콜론 형태
          frame_name: <프레임 이름>
          file_key: <생략 가능>      # config 기본값과 다를 때만
        sections:
          - slug: <섹션 slug>        # 지문 키 두 번째 조각. 바꾸지 않는다
            name: <섹션 이름>
            order: 1
            node_id: <node_id>       # 시안 이미지 대상
            anchor_text: <섹션 안 문구>  # 사람이 고치는 값. selector 의 씨앗
            selector: <CSS 셀렉터>     # 실행이 쓰는 파생값
            ignore: []
            capture: element         # element | viewport
            hide_fixed: true         # false면 고정 요소를 숨기지 않고 찍는다(헤더·탭바)
            degraded: false          # 높이 1500px 초과인데 내려갈 자식이 없는 섹션
            stale: ""                # 사유를 적으면 이 섹션만 건너뛰고 시안 대기
    flows:                           # 플로우 검사 — 화면 레벨. 캡처(피그마 프레임 수명)와 다른 물건(정답지 항목 수명)이라 캡처에 붙이지 않는다
      - source: <정답지 항목 ID>      # 정답지 파일 항목. 지문 키는 <화면 slug>/<source>, 같은 source 가 한 화면에 여럿이면 둘째부터 -2, -3
        note: <검사가 단언하는 것 한 줄>  # 사람이 원문을 다시 안 찾게
        confidence: guessed          # guessed | confirmed — setup 검증 한 바퀴를 통과한 검사만 confirmed
        before: []                   # 화면 path 도달 뒤 전제 조작. 도달 조작 3종 그대로
        steps: []                    # 검사 본체 조작. 도달 조작 3종 그대로
        expect:                      # 위에서 아래로 순서대로 평가. 원시어 다섯
          - url: <정규식>                   # 현재 URL 에 test. 포함 비교가 아닌 이유: 푸시 복귀는 "/chat/[^/]+$" 처럼 끝 경계가 필요하다
          - text: <문구>                   # 화면에 보인다
          - no_text: <문구>                # 화면에 보이지 않는다
          - attr: { text: <요소 문구>, name: <속성>, value: <값> }  # 문구로 찾은 요소의 속성값. browser_evaluate 로 읽는다 — a11y 스냅샷엔 aria-current 가 없다
          - back: true                     # browser_navigate_back 후 다음 expect 를 계속 평가
```

도달 조작은 셋뿐이다. 자유 자연어로 두지 않는다 — 실행마다 다르게 해석된다.

```yaml
before:
  - clickText: <정확히 일치하는 문구>
  - fillPlaceholder: { placeholder: <placeholder>, value: <값> }
  - scrollToText: <문구>
```

`clickText`는 정확 일치가 기본이고, 없으면 **그 문구로 시작하는 요소가 정확히 1개일 때** 그것을 누른다 — 탭 라벨에 카운트가 붙는 실물("종료 0")이 있다(2026-08-23 실측). 접두 일치도 여럿이면 누르지 않고 실패다.

| `status` | 뜻 | 사람이 할 일 |
| --- | --- | --- |
| `ready` | 찍는다 | 없음 |
| `unreached` | 도달 경로를 못 찾음 | 스텝을 적어 준다 |
| `blocked` | 자동 조작이 원리적으로 막힘(파일 업로드·서드파티 iframe) | 없음 |
| `unpaired` | 짝을 못 찾았거나 고유 문자열 2개 미만 | 프레임을 손으로 물려 준다 |

`ready`가 아닌 셋은 미커버로 센다. `stale` 섹션은 시안 대기라는 자기 칸이 있다.

**`scan`이 강등한 `unpaired`를 받으면 둘 중 어느 쪽인지부터 가른다.** 실행은 구분 못 한다 — 어느 쪽이 낡았는지는 결정 이슈가 안다.

| | 뜻 | 무엇을 하나 |
| --- | --- | --- |
| 틀린 짝 | 아예 다른 화면 | 프레임을 다시 물린다. 차이 목록은 전부 버린다 |
| 낡은 시안 | 같은 화면의 옛 버전 | 새 프레임으로. 없으면 낡은 섹션에 `stale`을 적고 나머지로 돈다 |

`stale`에는 사유를 반드시 적는다 — `헤더 타이틀만 결정 #1543 이전(2026-08-21 확인)`. "이 섹션만 낡았다"가 틀리면 남은 섹션이 죽은 기준으로 판정되고, 그 값은 적은 사람이 진다.

`confidence`는 **setup의 7번 검증**이 도달과 짝짓기를 둘 다 넘긴 줄을 `confirmed`로 올린다. `scan`은 `guessed`로 내리기만 한다.

`forbidden`은 가드다 — 대장을 갱신하다 완료 버튼을 스텝에 넣어 실제 주문을 만드는 사고를 막는다. 찍으면 안 되는 경계는 스텝 배열 자체가 표현한다.

헤더와 탭바는 QA 대상이다. 화면 `chrome` 한 줄에 섹션 둘, `hide_fixed: false`. 앱당 한 번이다.

## 초안을 채우는 순서

1. **기존 시각 회귀 하네스의 대상 목록을 씨앗으로.** 도달 스텝까지 실증된 줄이다. 주석도 옮긴다.
2. **페이지 프레임 트리를 파일로 떨군다.** `get_metadata` XML을 파일에 쓰고 스크립트로 씹는다 — 한 페이지 122K 토큰 관측. 필터: 페이지 이름 · 타입 `FRAME` · 폭이 뷰포트(390)에 가까운 것. `COMPONENT` 노드는 화면이 아니다.
3. **고유 문자열을 뽑는다.** 프레임마다 `TEXT` 레이어 이름을 모으고, 같은 페이지 다른 프레임에도 나오는 것과 2자 이하는 버린다. 한 프레임에서 2개 미만이면 그 프레임만 `get_design_context`를 한 번 더 부른다(문자열 리터럴이 생성 코드에 있다). **피그마 플러그인은 이 툴 앞에 `figma-design-to-code` 스킬 로드를 요구한다 — 먼저 로드한다.** 첫 setup에서 `TEXT` 레이어 이름이 실제 문자열을 주는지 확인해 확정한다.
4. **고유 문자열 겹침이 최대인 프레임을 짝으로.** 프레임 이름은 동점 깨기로만. 후보 범위는 `page_id` 한 장. 겹침 2개 미만이면 `unpaired`. 짝이 정해지면 고유 문자열 ≤5개를 `match_text`에 굳힌다.
5. **섹션을 고른다.** 프레임 직계 자식을 `y`로 정렬해 `order`. **높이 1500px 초과면 자식으로 한 겹 내려간다** — 판정 모델이 긴 변을 1568로 줄여 글자가 죽는다. 내려갈 자식이 없으면(단일 래퍼·긴 이미지 리프·인스턴스) `degraded: true`를 남기고 건너뛰지 않는다. `slug`·`name`은 자동 생성 이름이 아니라 내용을 보고 부여한다 — 지문 키가 여기 의존한다.
6. **`selector`를 앵커에서 유도한다.** `anchor_text`를 담은 요소에서 올라가 섹션 박스 조상을 유니크 CSS 셀렉터로 굳힌다. `browser_take_screenshot`의 `target`은 CSS 셀렉터를 받는다(`ref`는 일회용이라 대장에 못 적는다). 셀렉터가 썩으면 앵커에서 재유도해 확인받는다. 노드 하나로 안 잡히면 상위 노드를 지목하고 시안 경계를 다시 그린다 — 그러면 scan의 폭 게이트에 걸릴 수 있으니 `node_id`도 같은 범위로 맞춘다. 그래도 안 되면 `capture: viewport`.
7. **한 바퀴 돌려 자동 검증.** 캡처마다 `arrival_text` 도달과 `match_text` 겹침 2개를 확인한다. 대조 시점은 프라이밍 스크롤 뒤 — scan과 같은 시점이어야 한다. 통과한 줄을 `confirmed`로 올린다. **플로우도 이 바퀴에서 돈다** — 통과한 검사만 `confidence: confirmed`. 실패한 검사는 사람이 "검사가 틀림 / 진짜 결함"을 가르고, 진짜면 setup이 그 자리에서 시트 행을 만든다(ADR-0005). scan은 `confirmed` 검사 실패만 행으로 올린다 — 검사 자체가 틀리면 모든 실패가 오탐이라서다.
8. **사람에게 가는 것은 여섯.** 도달 실패 · `guessed` · `unpaired` · `anchor_text` 못 찾은 섹션 · `degraded` · `figma.version`이 바뀐 뒤의 `stale` 섹션 — 트랙 레포는 일곱째가 붙는다: 오라클 "시안과 다름" 항목의 `stale` 초안([`track-integration.md`](track-integration.md)). 버전이 바뀐 `stale`을 자동으로 걷지 않는다 — 버전이 움직였다는 사실만 신호고 판단은 사람이 한다. 통째 검수는 첫 setup에서 한 번 제안하되 건너뛸 수 있게.

## 정답지 파일 플로우 분해

`.qa/flows/*.yaml` **정답지 파일**을 병합해 읽고(파일 머리 `retired: true`는 건너뛴다) **`확정` 항목**을 원자 검사로 분해해 화면의 `flows:`에 넣는다(스키마는 위). 정답지는 이 파일뿐이다 — 스펙 이슈·티켓 AC·에이전트 추론은 기대값이 아니다([ADR-0005](../../../.agents/adr/0005-flow-answer-key-is-single-human-confirmed-source.md)). 트랙 레포에서 파일을 채우는 오라클 스냅샷은 [`track-integration.md`](track-integration.md), 요구사항 문서에서 채우는 추출은 확장 층의 몫이다 — setup은 출처를 묻지 않고 파일만 읽는다.

분해 규칙:

- **읽기 전용 조작만.** 전송·주문·첨부처럼 서버 상태를 바꾸는 조작은 화면의 `forbidden` 그대로다 — 검사 스텝에도 못 넣는다.
- **전제 없는 것부터.** 전제 상태(읽기 전용 방·빈 방·만료 임박·주문 이력)를 계정에 못 만드는 항목은 분해하지 않고 **미커버로 센다** — 침묵하지 않는다. 커버 비율(분해 가능 / 전체 확정)과 미커버 사유 목록을 setup 리포트에 찍는다.
- **데이터값을 기대로 굳히지 않는다.** 판매자명·상품명·금액이 기대에 들어가면 계정이 바뀔 때 검사가 썩는다 — 구조 문구(탭 라벨·앱바 제목·안내 카피)만 쓴다.
- **`잠정` 항목은 분해하지 않는다** — 미커버로 센다. 정책·규칙류 문장도 직접 분해하지 않는다 — 화면 기대 문장이 인용한다(오라클 출처면 ② 정책 층).

`expect`의 카피 문구는 정답지 문장이 명시한 것만 확정으로 쓰고, 구조만 말한 항목("제목 한 줄, 버튼 없음")은 부재 단언(`no_text`)으로 좁힌다 — 실물에서 읽은 카피를 기대로 되먹이면 검사가 항상 통과한다.

## 숨김·가드 배관

`scan` 6번의 두 호출. `SELECTOR`만 갈아 끼운다.

```js
// 숨김 + 가드. 촬영 전.
() => {
  const target = document.querySelector(SELECTOR);
  const box = target.getBoundingClientRect();
  const isFixed = el => ['fixed', 'sticky'].includes(getComputedStyle(el).position);
  const outside = [...document.querySelectorAll('*')].filter(el => isFixed(el) && !target.contains(el));
  outside.forEach(el => {
    el.dataset.dqaHidden = el.style.getPropertyValue('visibility') || '';
    el.style.setProperty('visibility', 'hidden', 'important');
  });
  const leftover = outside.filter(el => {
    if (getComputedStyle(el).visibility === 'hidden') return false;
    const r = el.getBoundingClientRect();
    return r.bottom > box.top && r.top < box.bottom && r.right > box.left && r.left < box.right;
  }).length;
  return { hidden: outside.length, leftover, box: box.toJSON() };
}
```

```js
// 복원. 촬영 후. 안 풀면 다음 섹션이 빈 헤더를 찍는다.
() => {
  document.querySelectorAll('[data-dqa-hidden]').forEach(el => {
    el.style.setProperty('visibility', el.dataset.dqaHidden);
    delete el.dataset.dqaHidden;
  });
}
```

## 뷰포트는 390이다

하네스의 375가 아니다(`config.yaml`에서 덮는다). 390은 breakpoint를 넘지 않아 375의 레이아웃 분기를 보면서 시안 폭에 맞춘다. MCP 인자 `--viewport-size=390x844`. 세션 파일은 환경변수 `PLAYWRIGHT_MCP_STORAGE_STATE`로 넘어간다 — `--isolated` 없이 `--storage-state`만 주면 조용히 무시된다. 환경변수는 셸 export 가 아니라 대상 레포 `.claude/settings.local.json` 의 `env` 블록으로 준다 — 설정의 `env` 는 세션과 자식 프로세스(MCP 서버)에 적용되고 런처가 GUI 든 터미널이든 같다. 셸 rc 의 export 는 GUI 런처로 뜬 Claude Code 에 닿지 않는다(2026-08-22 실측, [`rationale.md`](rationale.md#세션-경로가-우회로로-간-이유)).

## 세션 파일

`<플러그인>/skills/qa/scripts/qa-session-wizard.sh` — 브라우저 확인 → 파일 자리·gitignore 검사 → 헤디드 로그인·덤프 → MCP로 검증 촬영 → `.claude/settings.local.json` `env` 등록(셸 export 는 선택) → 세션 재시작. 만료는 수동 갱신.

검증은 CLI가 아니라 MCP 표면에서 한다 — CLI `playwright screenshot`에는 `--grant-permissions`가 없어 앱이 `Network Error`만 그린다. `<플러그인>/skills/qa/scripts/verify-shot.mjs`(위저드 4단계가 부른다)가 같은 플래그로 한 장 찍고 실패 모양을 종료코드로 알린다.
