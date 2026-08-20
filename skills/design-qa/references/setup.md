# setup — 화면 대장 만들기와 갱신하기

`scan`이 읽는 자산을 짓는다. AI가 초안을 다 채우고 **한 바퀴 돌려 자동 검증**하며, 사람은 **걸러진 줄만** 본다. 전량 검수를 요구하면 검수가 새 병목이 된다 — 이 도구의 목적이 병목 줄이기다.

돌리는 때: 대장이 없을 때 · 시안이 바뀌었을 때(`figma.version` 불일치) · `scan`이 `짝짓기 실패`나 `미커버`를 보고했을 때.

## 사는 곳

대상 레포 안 `.design-qa/`. **커밋되는 파일은 `.gitignore` 한 줄뿐이다.**

```
.design-qa/
  ledger.yaml            # 대장 — 앱 단위. 트랙보다 오래 산다
  config.yaml            # 존 URL·피그마 기본값·시트 URL·세션 경로·뷰포트·동적 식별자·진입 상태
  storage-state.json     # 로그인 세션. design-qa-session-wizard.sh 가 만든다
  cache/<file_key>/<figma.version>/<node_id>.png
```

`.gitignore`에 `.design-qa/`와 `.playwright-mcp/` 두 줄(뒤엣것은 MCP가 서버 cwd에 떨구는 콘솔·스냅샷 부산물이다).

두 파일로 가르는 이유는 **수명이 다르다**는 것뿐이다. 대장은 앱 단위이고 설정은 존 배정·트랙마다 갈린다. 동적 세그먼트 식별자는 환경변수가 아니라 `config.yaml`에 직접 적는다 — gitignore된 폴더를 확보했으므로 환경변수 우회가 필요 없고, 환경변수는 쓸 때마다 사람이 셸을 준비해야 해서 재현이 사람 손에 달린다.

포맷은 YAML이다. **주석이 사람 검수 자산의 본체다** — "이 제안 유형은 허용된 조작으로 못 뚫린다", "여기서 완료를 누르면 실제 주문이 나간다". JSON은 주석을 못 쓰고, 노션 코드블록은 블록당 문자 상한이 걸려 중첩 YAML이 조각나며 그 조각을 갈아끼우다 실패하면 검수를 거친 자산이 깨진다.

## 대장 스키마

계층은 **화면 > 캡처 > 섹션**이다. 위저드는 URL 하나에 화면 여러 장이고 스텝마다 시안 프레임이 따로 있으므로, `frame_id`와 `sections[]`는 화면이 아니라 **캡처**에 붙는다. 화면이 담는 것은 도달 경로에 관한 것뿐이다.

```yaml
version: 1

figma:
  # 파일 단위 lastModified 스냅샷. 피그마는 노드별 수정시각을 주지 않으므로
  # 갱신 감지의 유일한 축이고, 그래서 줄이 아니라 머리말에 둔다.
  version: <ISO 8601>
  source: <스펙 이슈 링크>     # 피그마 URL을 캐낸 자리. 없으면 사람에게 직접 묻는다

screens:
  - slug: <화면 slug>          # 지문 키 첫 조각. 한 번 정하면 바꾸지 않는다
    name: <화면 이름>           # 표시용
    path: /<라우트>            # config 키는 {중괄호}로 참조한다
    status: ready              # ready | unreached | blocked | unpaired
    confidence: confirmed      # confirmed | guessed
    requires: []               # config 키 이름 목록. 하나라도 비면 이 화면은 스킵하고 미커버로 센다
    forbidden: []              # 어떤 경우에도 clickText 하지 않는 문구
    captures:
      - step: ""               # 스텝 없는 화면은 빈 문자열 — 지문 키에 조각이 안 붙는다
        captured: true         # false면 조작만 하고 찍지 않는다(경유 스텝)
        arrival_text: <이 화면에만 보이는 문구>
        match_text: []         # 짝짓기 대조용 고유 문자열 ≤5. 파생값 — 사람이 만들지 않는다
        before: []             # 도달 조작
        figma:
          page_id: <page_id>
          frame_id: <frame_id>      # 콜론 형태
          frame_name: <프레임 이름>
          file_key: <생략 가능>      # config 기본값과 다른 파일·브랜치에서 올 때만
        sections:
          - slug: <섹션 slug>        # 지문 키 두 번째 조각. 한 번 정하면 바꾸지 않는다
            name: <섹션 이름>         # 표시용
            order: 1
            node_id: <node_id>       # 시안 이미지를 뽑는 대상
            anchor_text: <섹션 안 문구>  # 사람이 읽고 고치는 값. selector 의 씨앗
            selector: <CSS 셀렉터>     # 실행이 쓰는 파생값. 앵커에서 유도해 굳힌다
            ignore: []               # 이 섹션에만 걸리는 추가 무시 항목
            capture: element         # element | viewport (노드 하나로 안 잡히는 섹션의 후퇴)
            hide_fixed: true         # false면 고정 요소를 숨기지 않고 찍는다(헤더·탭바 줄)
            degraded: false          # true면 높이 상한에 걸렸으나 내려갈 자식이 없는 섹션
```

도달 조작은 세 종류다. 단일 키 맵으로 적는다.

```yaml
before:
  - clickText: <정확히 일치하는 문구>
  - fillPlaceholder: { placeholder: <placeholder>, value: <값> }
  - scrollToText: <문구>
```

자유 자연어로 두지 않는다 — 대장을 도입한 이유 자체가 재현이고, 자유 서술은 에이전트가 실행마다 다르게 해석한다. 좁힌 어휘도 사람이 읽고 고칠 수 있어 목적은 유지된다.

**표기 축은 둘이고, 가르는 값은 "사람이 할 일이 다르다"는 것이다.**

| `status` | 뜻 | 사람이 할 일 |
| --- | --- | --- |
| `ready` | 찍는다 | 없음 |
| `unreached` | 도달 경로를 못 찾음 | 스텝을 적어 준다 |
| `blocked` | 자동 조작이 원리적으로 막힘(파일 업로드·서드파티 iframe) | 없음. 영구히 못 찍는다 |
| `unpaired` | 짝을 못 찾았거나 고유 문자열이 2개 미만 | 프레임을 손으로 물려 준다 |

`ready`가 아닌 셋은 전부 리포트의 **미커버 N개**에 센다.

`confidence`는 `confirmed` | `guessed`다. **도달 검증과 짝짓기 게이트를 둘 다 넘긴 줄은 `confirmed`로 승격한다** — 사람 검수 대상 선별이 이 값을 읽는다.

**"찍으면 안 되는 경계"는 스텝 배열 자체가 표현한다** — 마지막 캡처가 그 경계다. `forbidden`은 상태 표기가 아니라 **가드**다: 대장을 갱신하다 완료 버튼을 스텝에 넣어 실제 주문을 만드는 사고를 막는 자리다.

헤더와 탭바는 QA 대상으로 남긴다 — 로고·타이틀 문구·탭 아이콘·활성 탭 색은 폴리싱 결함이 사는 대표적인 자리다. 화면 `chrome` 한 줄에 섹션 둘로 두고 `hide_fixed: false`를 준다. 화면마다가 아니라 **트랙당 한 번**이다(화면이 바뀌어도 같은 물건이다).

## 초안을 채우는 순서

1. **기존 시각 회귀 하네스의 대상 목록을 씨앗으로 흡수한다.** 도달 스텝까지 실증된 줄이 이미 있다 — 다시 유도할 이유가 없다. 그 파일의 주석도 같이 옮긴다.

2. **페이지 전체 프레임 트리를 파일로 떨군다.** `get_metadata`를 페이지에 걸어 받은 XML을 파일에 쓰고 **스크립트로 씹는다.** 한 페이지가 489,273자(약 122K 토큰)로 관측됐다 — 컨텍스트에 통째로 올리면 한 페이지에서 죽는다.

   화면 프레임을 고르는 필터 셋: 페이지 이름으로 거르고, 타입이 `FRAME`인 것만 취하고, 폭이 뷰포트(390)에 가까운 것만 취한다. 컴포넌트 라이브러리 페이지의 `COMPONENT` 노드는 화면이 아니다. 크기는 `get_metadata`가 이미 준다.

3. **고유 문자열을 뽑는다.** 프레임마다 텍스트 문자열을 모으고, **같은 페이지의 다른 프레임에도 나오는 문자열은 버린다** — 헤더·탭바·공통 CTA 문구는 모든 화면에 다 있어서 틀린 짝도 통과시킨다. 2자 이하 문자열도 버린다(우연 일치).

   문자열의 출처는 `get_metadata`의 `TEXT` 레이어 이름이다(추가 호출 0). 한 프레임에서 고유 문자열이 2개 미만으로 나오면 사람에게 던지기 전에 **그 프레임만** `get_design_context`를 한 번 더 부른다 — 생성 코드에 문자열 리터럴이 들어 있다. 이름이 바뀐 레이어는 화면 전체에 고르게 퍼지지 않고 프레임 단위로 뭉친다(디자이너가 한 화면을 정리한다).

   **첫 setup 실행에서 `TEXT` 레이어 이름이 실제로 문자열을 주는지 확인해 확정한다.** 안 주면 `get_design_context`가 기본이 되고 페이로드 비용이 여기 붙는다.

4. **고유 문자열 겹침이 최대인 프레임을 짝으로 고른다.** 프레임 이름은 동점 깨기로만 쓴다 — 결과 화면 계열은 같은 화면이 진입 경로마다 다른 프레임으로 그려져 있고 이름이 진입 사유로 붙어 있어서, 이름 짝짓기는 원리적으로 약하다. 라우트 트리와 각 화면의 제목 문구를 후보 목록으로 쓴다(코드의 한글 제목이 프레임 이름과 글자 단위로 같은 경우가 많다).

   겹침이 2개 미만인 화면은 `status: unpaired`로 두고 사람에게 보낸다. 후보 범위는 `page_id` 한 장이다 — 파일 전체로 넓히면 페이로드가 장수만큼 곱해지고, 고유 문자열이 관계없는 화면 때문에 과하게 깎인다.

   짝이 정해지면 그 프레임의 고유 문자열 **≤5개를 `match_text`에 굳힌다.**

5. **섹션을 고른다.** 프레임의 직계 자식을 **`y`로 정렬해** `order`를 붙인다 — 메타데이터의 자식 순서는 시각 순서가 아니다.

   **노드 높이가 1500px를 넘으면 그 노드를 섹션으로 잡지 않고 자식으로 한 겹 내려간다.** 판정 모델이 긴 변을 1568px로 다시 줄이므로 390x2540 섹션은 241x1568이 되어 12px 글자가 7px가 된다 — `문구`·`에셋` 갈래가 긴 섹션에서 통째로 죽는다. 런타임 코드 0줄로 막는 자리가 여기다.

   내려갈 자식이 없는 길이 셋 있다: 자식 하나뿐인 래퍼 · 긴 이미지 리프 · **인스턴스**(인스턴스 내부 노드는 메타데이터에 아예 안 나온다. 디자인 시스템을 쓰는 파일에서 가장 흔하다). 그 섹션은 **건너뛰지 않고 축소된 채 판정하되** `degraded: true`를 남긴다 — 축소돼도 `누락`·`잉여`·`컬러`처럼 덩치 큰 갈래는 살아남는다.

   프레임 트리의 이름은 대부분 자동 생성 이름이라 섹션 이름으로 쓸 수 없다. `slug`와 `name`은 그 섹션의 내용을 보고 부여한다 — 지문 키가 이 값에 직접 의존하고, 디자이너 리네임과 시안 재작업에 둘 다 안 죽는 유일한 축이다.

6. **`selector`를 앵커에서 유도한다.** `anchor_text`를 담은 요소에서 올라가 섹션 박스에 해당하는 조상을 찾아 유니크 CSS 셀렉터로 굳힌다. `browser_take_screenshot`의 `target`은 `ref`뿐 아니라 유니크 CSS 셀렉터를 받는다 — 접근성 트리를 우회하므로 의미 없는 래퍼 요소도 지목된다(`ref`는 스냅샷마다 새로 발급되는 일회용 핸들이라 대장에 적을 수 없다).

   실행마다 노드를 휴리스틱으로 유도하는 안은 버렸다 — DOM이 바뀔 때 프레이밍이 조용히 달라져 대장의 존재 이유인 재현이 깨진다. 셀렉터가 썩으면 앵커에서 재유도해 사람에게 확인받는다. **사람이 손대는 값은 여전히 문구다.**

   노드 하나로 안 잡히는 섹션은 상위 노드를 지목하고 시안 쪽 섹션 경계를 그 범위로 다시 그린다. 그래도 안 되면 그 섹션만 `capture: viewport`로 후퇴한다. 대장에서 빼고 미커버로 세는 것은 마지막 수단이다.

7. **한 바퀴 돌려 자동 검증한다.** 대장 초안대로 실제로 돌면서 캡처마다 **`arrival_text` 도달**과 **`match_text` 겹침 2개**를 확인한다. 코드만 읽고 유도한 스텝은 사람 검수로도 안 걸러진다 — 사람도 코드만 보고는 모른다. 한 바퀴 돌면 틀린 줄이 그 자리에서 다 드러난다.

   **대조 시점은 프라이밍 스크롤 뒤다.** `scan`과 다른 시점의 DOM을 보면 여기서 굳힌 `match_text`가 실행에서 안 맞는다.

8. **사람에게 가는 것은 다섯이다.** 도달 실패 · `confidence: guessed` · `unpaired` · `anchor_text`를 못 찾은 섹션 · `degraded: true`. 도달과 짝짓기를 둘 다 넘긴 줄에는 스크린샷이라는 증거가 남아 사람이 볼 게 없다. 통째 검수는 첫 setup에서 한 번 제안하되 건너뛸 수 있게 둔다.

## 숨김·가드 배관

`scan`의 6번이 쓰는 한 호출이다. 형태만 남긴다 — 셀렉터만 갈아 끼운다.

```js
() => {
  const target = document.querySelector(SELECTOR);
  const box = target.getBoundingClientRect();
  let hidden = 0;
  document.querySelectorAll('*').forEach(el => {
    const p = getComputedStyle(el).position;
    if ((p === 'fixed' || p === 'sticky') && !target.contains(el)) {
      el.style.setProperty('visibility', 'hidden', 'important');
      hidden++;
    }
  });
  // 가드: 숨긴 뒤에도 대상 박스와 겹치는 고정 요소가 남았는가
  const leftover = [...document.querySelectorAll('*')].filter(el => {
    const p = getComputedStyle(el).position;
    if (p !== 'fixed' && p !== 'sticky') return false;
    if (target.contains(el)) return false;
    if (getComputedStyle(el).visibility === 'hidden') return false;
    const r = el.getBoundingClientRect();
    return r.bottom > box.top && r.top < box.bottom && r.right > box.left && r.left < box.right;
  }).length;
  return { hidden, leftover, box: box.toJSON() };
}
```

## 뷰포트는 390이다

하네스가 쓰는 375가 아니다(`config.yaml`에서 덮을 수 있다). 판정이 픽셀 diff가 아니라 VLM 서술이고 갈래에 여백·크기가 있어서, 실물 폭이 시안 폭과 다르면 반응형으로 정상적으로 벌어진 여백이 불일치로 잡힌다. 390은 breakpoint 경계를 넘지 않아 **375에서 보이는 레이아웃 분기를 그대로 보면서** 시안 폭에 맞춘다.

MCP 서버 인자에 `--viewport-size=390x844`로 박혀 있다(기기 프리셋을 쓰지 않는다). 세션 파일 경로는 환경변수 `PLAYWRIGHT_MCP_STORAGE_STATE`로 넘어가고, `--isolated` 없이 `--storage-state`만 주면 **에러도 경고도 없이 세션이 무시된다.**

## 세션 파일

`.agents/design-qa/design-qa-session-wizard.sh` — 브라우저 확인 → 파일 자리와 gitignore 검사 → 헤디드 로그인·덤프 → MCP로 검증 촬영 → 환경변수 등록. 만료는 수동 갱신이다(자동 갱신 없음).

검증은 CLI가 아니라 **MCP 표면에서** 해야 한다. `npx playwright screenshot --load-storage`에는 `--grant-permissions`가 없어 사설망 API 요청이 거부되고 앱이 `Network Error`만 그린다 — 같은 이유로 라이브러리 탈출구를 쓸 때도 권한에서 두 표면이 갈린다. `.agents/design-qa/verify-shot.mjs`가 MCP를 같은 플래그로 띄워 한 장 찍고 실패 모양을 종료코드로 알린다.
