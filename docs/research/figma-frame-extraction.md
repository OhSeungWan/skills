# 피그마에서 프레임 트리와 섹션 이미지를 어떻게 얻나

> 리서치 티켓: #3 (맵 #1 · 자동 디자인 QA 스킬 찾아가기)
> 작성일: 2026-08-12

## 이 문서가 답하려는 것

화면 대장(screen ledger)의 모집단은 피그마 프레임이고, 판정 단위는 섹션 크롭이다.
그 둘을 실제로 어떤 도구로, 몇 번의 호출로 얻는지를 확정한다. 마지막 절에
**대장 한 줄이 담아야 할 피그마 식별자**를 결론으로 적는다.

## 조사한 두 개의 표면(surface)

피그마를 읽는 경로는 두 가지이고, 능력이 서로 다르다. 이 문서는 어떤 능력이
어느 표면에서 나오는지를 매번 밝힌다.

| 표면 | 인증 | 이 세션에서 사용 가능한가 |
|---|---|---|
| **Figma MCP 서버** (`plugin:figma:figma`) | 로그인된 피그마 계정 세션. 별도 토큰 불필요 | 예. `whoami`를 실제로 호출해 인증 상태를 확인했다 |
| **Figma REST API** (`api.figma.com`) | 개인 액세스 토큰(`X-Figma-Token` 헤더) 또는 OAuth 베어러 | 아니오. 이 세션에 토큰이 없다 |

MCP 표면의 근거는 이 세션에 로드된 **도구 스키마 원문**이다. 도구 설명과 파라미터
제약(정규식, 기본값, 최대/최소값)은 서버가 직접 선언한 계약이므로 1차 출처로 취급했다.
여기에 피그마 플러그인이 배포하는 스킬 문서를 함께 읽었다 —
`figma-use/SKILL.md`, `figma-design-to-code/SKILL.md`,
`figma-use/references/validation-and-recovery.md`,
`figma-use/references/plugin-api-standalone.d.ts`.

REST 표면의 근거는 피그마 공식 문서와 피그마가 직접 배포하는 OpenAPI 명세다.

- `https://developers.figma.com/docs/rest-api/` (구 `figma.com/developers/api`는 여기로 301 리다이렉트된다)
- `https://github.com/figma/rest-api-spec` → `openapi/openapi.yaml` — 기계가 읽는 정본이고, 산문 문서보다 정확하다. 아래 필드명·기본값 인용은 대부분 여기서 나왔다
- `https://developers.figma.com/docs/rest-api/rate-limits/`
- `https://developers.figma.com/docs/rest-api/scopes/`
- `https://developers.figma.com/docs/rest-api/webhooks-events/`
- `https://developers.figma.com/docs/plugins/api/properties/nodes-id/`

### 실물 검증 범위에 대한 정직한 고백

이 리서치는 **실제 피그마 파일을 대상으로 한 호출 검증을 하지 못했다.**
이 머신의 프로젝트 파일 전체를 훑어 이미 참조된 피그마 파일 URL을 찾았으나
(`figma.com/design|file|board/...` 패턴 전수 검색) 실제 파일 키가 박힌 URL은
하나도 없었다. 발견된 것은 모두 문서 안의 예시 URL(`:fileKey` 같은 자리표시자)뿐이었다.
이 레포가 공개라는 제약상 사내 파일 키를 새로 끌어올 수도 없다.

따라서 아래 내용 중 **실제로 호출해 확인한 것은 `whoami` 하나뿐**이다.
나머지는 도구 스키마와 공식 문서에 근거하며, 실측이 필요한 항목은 본문에
`미검증`으로 표시했다. 프로토타입 단계에서 대상 레포의 실제 파일로 반드시 다시 때려봐야 한다.

---

## 1. 파일 키만으로 프레임 목록을 열거할 수 있나

**결론: 할 수 있다. 페이지 → 프레임 두 단계다. MCP만으로 충분하고 REST 토큰이 필요 없다.**

### MCP 경로 — `get_metadata`

`get_metadata`의 파라미터는 `fileKey`(필수)와 `nodeId`(선택) 둘뿐이다.
이 `nodeId`의 선택성이 열거의 열쇠다.

- **`nodeId`를 생략하면** XML 덤프 대신 **문서의 최상위 페이지 목록(guid + name)** 이
  돌아온다. 도구 설명이 명시한다 — "when omitted, the tool returns a list of the
  top-level pages (guid + name) in the document instead of an XML dump — use this
  when you don't yet know which page or node to drill into."
  즉 파일 키만 있으면 페이지를 열거할 수 있다.
- **`nodeId`에 페이지 id(예: `0:1`)를 주면** 그 페이지의 구조를 XML로 돌려준다.
  포함되는 정보는 **노드 ID, 레이어 타입, 이름, 위치, 크기**뿐이다.
  페이지의 직계 자식이 곧 그 페이지의 최상위 프레임이므로, 이 한 번의 호출로
  프레임 목록이 나온다.

`fileKey`는 정규식 `^[0-9a-zA-Z]{22,128}$`로 검증된다. URL
`https://figma.com/design/<file-key>/<file-name>?node-id=1-2`에서 뽑는다.
REST 문서도 같은 규칙을 일반화해 적어 두었다 —
`https://www.figma.com/:file_type/:file_key/:file_name`. 즉 `design`, `file`,
`board`, `proto`, `slides` 어느 쪽이든 **세 번째 경로 조각이 파일 키**다.

브랜치 URL(`/design/<file-key>/branch/<branch-key>/<file-name>`)이면
**브랜치 키를 파일 키 자리에 넣어야 한다.** MCP 도구 설명이 네 개 도구 모두에서
같은 문장으로 반복 경고한다. 대장이 브랜치 시안을 가리킬 수 있다면 이건 함정이다.

노드 id에도 함정이 하나 있다. **URL의 노드 id는 하이픈이고 API는 콜론을 쓴다.**
플러그인 문서가 직접 말한다 — "In the URLs for Figma files, node ids are hyphenated.
However, for use with the API, node ids must use colons." (`node-id=1-3` → `1:3`).
MCP 도구는 정규식 `^\d+[:-]\d+$`로 둘 다 받아주지만, REST로 내려가면 콜론이어야 한다.
**대장에는 콜론 형태로 저장하는 게 안전하다.**

제약 하나: `get_metadata`는 **디자인 파일(`/design/`) 전용**이다.
FigJam(`/board/`), Slides(`/slides/`), Make(`/make/`)에서는 동작하지 않는다.
디자인 QA 스코프에서는 문제되지 않는다.

### 페이지 / 프레임 / 컴포넌트가 구분되나

구분된다. `get_metadata`의 XML이 **layer type**을 실어주므로
`FRAME` / `COMPONENT` / `COMPONENT_SET` / `INSTANCE` / `SECTION` / `TEXT` 등이
그대로 읽힌다. 플러그인 API 타입 정의에도 `SECTION`은 독립 노드 타입으로 존재한다
(`interface SectionNode { readonly type: 'SECTION' }`).

이게 대장 작성에 중요한 이유는 **화면 프레임과 디자인 시스템 컴포넌트를 구분해야
하기 때문**이다. 컴포넌트 라이브러리 페이지의 `COMPONENT` 노드는 화면이 아니다.
실무적으로는 (1) 페이지 이름으로 거르고, (2) 타입이 `FRAME`인 것만 취하고,
(3) 폭이 뷰포트(390)에 가까운 것만 취하는 세 겹 필터가 현실적이다.
크기는 `get_metadata`가 이미 주므로 추가 호출이 없다.

### REST 경로 — 페이로드를 통제해야 할 때

`GET /v1/files/<file-key>`는 문서 전체를 반환한다. 트리는
`document`(`type: "DOCUMENT"`) → `children`(`CANVAS` = 페이지) → `children`(프레임 등)
구조다. 여기에 **`depth` 쿼리 파라미터**가 있고, 명세의 설명이 정확히 우리가 원하는 것이다 —
"setting this to 1 returns only Pages, setting it to 2 returns Pages and all top level
objects on each page."

즉 **`GET /v1/files/<file-key>?depth=2`가 "페이지별 최상위 프레임 목록"을 얻는
문서화된 유일한 경로**다. 프레임만 나열해주는 전용 엔드포인트는 없다.

주의할 quirk도 명세에 적혀 있다. `ids`로 일부만 요청해도
"top-level canvas nodes are always returned, regardless of whether they are listed
in the `ids` parameter" — 페이지 노드는 항상 딸려온다.

**판정: 프레임 열거는 MCP로 충분하다. 이 목적만으로는 REST 토큰이 불필요하다.**

---

## 2. 프레임 안의 섹션 단위 자식 노드를 트리로 받을 수 있나

**결론: 받을 수 있다. MCP에서는 1번과 같은 호출에 공짜로 딸려온다 — 그게 장점이자 문제다.**

`get_metadata`에는 **`depth` 파라미터가 없다.** 스키마에 `fileKey`와 `nodeId`뿐이다.
즉 프레임 노드 id를 주면 **그 프레임의 서브트리 전체**가 XML로 돌아온다.
깊이를 잘라 받을 방법이 없다.

이건 양면적이다.

- **좋은 쪽**: 프레임 한 번 조회로 섹션 후보(직계 자식)와 그 아래 구조까지 다 보인다.
  섹션 경계를 에이전트가 트리를 보고 판단할 수 있다.
- **나쁜 쪽**: 화면 하나의 서브트리는 노드 수백 개일 수 있고, 그게 전부 컨텍스트로
  들어온다. 화면 수십 개면 컨텍스트가 먼저 죽는다.

깊이 통제가 필요하면 REST로 내려간다.
`GET /v1/files/<file-key>/nodes?ids=<node-id>&depth=1`이 답이고,
**여기서 `depth`의 의미가 파일 엔드포인트와 다르다**는 점이 명세에 경고로 붙어 있다 —
"this parameter behaves differently from the same parameter in the
`GET /v1/files/:key` endpoint. In this endpoint, the depth will be counted starting
from the desired node rather than the document root node."
프레임 기준 `depth=1`이면 딱 직계 자식, 즉 섹션 후보만 온다.

### 어느 깊이가 "섹션"인가

여기에 **도구가 대신 답해주는 정답은 없다.** 피그마의 `SECTION` 노드 타입은
캔버스 위에서 프레임들을 묶는 조직 도구이지, 화면 내부의 시각적 구획이 아니다.
맵 #1이 말하는 "섹션 크롭"의 섹션은 화면 안의 헤더 / 배너 / 리스트 / CTA 같은
**시각적 덩어리**이고, 이건 대개 화면 프레임의 **직계 자식 오토레이아웃 프레임**에
대응한다.

그래서 실무 규칙은 이렇게 잡는 게 맞다.

1. 화면 프레임의 **직계 자식(depth 1)** 을 섹션 후보로 본다.
2. 직계 자식이 1개뿐인 래퍼 프레임이면(오토레이아웃 컨테이너 한 겹) 한 단계 더 내려간다.
3. 자식이 너무 잘게 쪼개져 있으면(예: 15개) 시각적으로 인접한 것들을 묶는 판단이 필요하다.
   이건 규칙으로 못 박기보다 **레이어 이름을 신뢰**하는 편이 낫다 — 디자이너가
   `Header`, `배너`, `상품 리스트`처럼 이름을 붙여두었다면 그게 가장 좋은 섹션 경계다.

`get_metadata`가 레이어 이름과 x/y/w/h를 함께 주므로 위 세 판단을 추가 호출 없이 할 수 있다.
이게 이 도구의 진짜 값어치다.

**중요한 함의: 섹션 경계는 실행 때마다 재판정할 것이 아니라 대장에 박아두는 값이어야 한다.**
매번 트리를 다시 보고 섹션을 다시 나누면 실행마다 결과가 달라져 맵 #1의 제약 5
("자율 탐색은 실행마다 결과가 달라져 재현이 안 된다")를 정면으로 위반한다.
섹션 노드 id를 대장에 고정해야 한다.

---

## 3. 임의 노드 ID로 이미지를 받을 수 있나 — 배율·포맷·투명배경

**결론: 받을 수 있다. 다만 통제 손잡이가 세 곳에 흩어져 있고, 기본값이 표면마다 다르다.**

### `get_screenshot` (MCP) — 크롭 뽑기의 주력

| 파라미터 | 값 | 비고 |
|---|---|---|
| `fileKey` | 필수 | |
| `nodeId` | **필수**, 정규식 `^\d+[:-]\d+$` | |
| `maxDimension` | 기본 1024, 최대 65536 | 긴 변 픽셀 상한. 종횡비 유지 |
| `contentsOnly` | **기본 false** | true면 고립 렌더 — 떠 있는 요소 제외 |
| `enableBase64Response` | 기본 false | |

성질:

- **포맷은 PNG 고정이다.** 포맷 파라미터가 없다.
- **배율(scale) 파라미터가 없다.** 대신 `maxDimension`으로 긴 변 상한을 준다.
  응답 JSON에 `width`/`height`(렌더된 PNG 크기)와
  `original_width`/`original_height`(노드의 캔버스 원본 크기)가 함께 오므로,
  더 크게 다시 받을지 판단할 수 있다. **뷰포트 390의 세로로 긴 모바일 화면을
  1:1로 받으려면 `maxDimension`을 원본 높이 이상으로 올려야 한다** — 기본 1024는
  그런 화면을 크게 축소해버린다. VLM 판정 품질에 직결되므로 실측이 필요하다. `미검증`
- **투명 배경 파라미터는 없다.** 프레임에 배경 fill이 있으면 그 색으로 렌더된다.
  QA 대조용으로는 오히려 이게 맞다 — 스테이징 스크린샷도 배경이 있으니까.
- **기본 응답은 짧은 수명의 URL + curl 사용법**이고 인라인 base64가 아니다.
  도구 설명이 못 박는다 — "the URL+curl path is strongly preferred because it uses
  far fewer tokens than embedding the image inline."
  **디자인 QA 스킬은 반드시 URL 경로를 써야 한다.** 수십 장의 크롭을 base64로 받으면
  컨텍스트가 즉사한다. 받은 URL을 curl로 파일에 떨궈두고, VLM 판정 시점에만 읽는 구조가 맞다.
- 디자인·FigJam·Slides 모두 지원. Make는 미지원.

`nodeId` 정규식이 `^\d+[:-]\d+$`인 점을 눈여겨봐야 한다.
`get_metadata`는 인스턴스 내부 노드 id(`I123:456;789:012` 형태)를 받지만
**`get_screenshot`은 정규식상 받지 않는다.** 섹션이 컴포넌트 인스턴스 내부 노드라면
스크린샷을 못 찍는다. 섹션 경계는 인스턴스 바깥의 일반 노드로 잡아야 한다.
`미검증` — 스키마 정규식에서 읽은 제약이며 실제 거부 여부는 확인하지 못했다.

### `download_assets` (MCP) — 포맷과 배율이 필요할 때

| 파라미터 | 값 |
|---|---|
| `fileKey` | 필수 |
| `nodeId` | 필수, 정규식 `^\d+[:-]\d+$` |
| `defaultFormat` | `png` \| `jpg` \| `svg` \| `pdf` |
| `defaultScale` | 0.01 ~ 4 |

반환은 세 덩어리다 — `export`(노드 전체의 익스포트 이미지),
`rawImages`(서브트리 안의 원본 업로드 이미지, 최대 20개),
`svgAssets`(벡터 레이어 SVG, 최대 20개).

익스포트 우선순위 규칙이 명시돼 있다. `defaultFormat`/`defaultScale`을 주면
**피그마 노드에 설정된 익스포트 세팅을 덮어쓴다.** 생략하면 노드 설정을 쓰고,
그것도 없으면 png @ 1x. 따라서 **2x 크롭이 필요하면
`download_assets(defaultFormat='png', defaultScale=2)`** 가 답이지 `get_screenshot`이 아니다.

URL은 임시다("URLs are temporary — download promptly"). `figma-design-to-code` 스킬은
에셋 URL 수명을 **약 7일**로 적고 있다.

### `GET /v1/images/<file-key>` (REST) — 배치가 필요할 때의 유일한 답

명세가 밝힌 전체 파라미터와 **기본값**이다. MCP와 기본값이 다른 항목이 있으니 주의.

| 파라미터 | 값 | 기본값 |
|---|---|---|
| `ids` | **필수**, 노드 id 쉼표 구분 | — |
| `format` | `jpg` \| `png` \| `svg` \| `pdf` | `png` |
| `scale` | 0.01 ~ 4 | — |
| `contents_only` | boolean | **`true`** (MCP `get_screenshot`은 false) |
| `use_absolute_bounds` | boolean | `false` — "Use the full dimensions of the node regardless of whether or not it is cropped" |
| `version` | 특정 버전 id | — (현재 버전) |
| `svg_outline_text` / `svg_include_id` / `svg_include_node_id` / `svg_simplify_stroke` | SVG 전용 | `true` / `false` / `false` / `true` |

응답은 `{ err, images }`이고 `images`는 노드 id → URL 맵이다.

문서화된 성질 중 설계에 직접 영향을 주는 것 셋:

1. **URL 수명 30일** — "The image assets will expire after 30 days."
   MCP의 "short-lived"보다 훨씬 길다. 크롭 캐시를 붙일 거라면 이쪽이 유리하다.
2. **32메가픽셀 상한** — "Images up to 32 megapixels can be exported. Any images that
   are larger will be scaled down." 390×3000 = 약 1.2메가픽셀이니 2x(4.7MP)로 떠도 여유가 있다.
3. **부분 실패가 정상 동작이다** — "the image map may contain values that are `null`.
   This indicates that rendering of that specific node has failed… It is guaranteed
   that any node that was requested for rendering will be represented in this map
   whether or not the render succeeded."
   **배치를 쓰면 반드시 null 검사를 해야 한다.** 조용히 빠진 섹션은 맵 #1 제약 14가
   금지하는 "조용한 누락"이 된다.

**판정: 크롭 한두 장이면 MCP `get_screenshot`, 수십 장을 한 번에 뽑아야 하면 REST `/v1/images`.**

---

## 4. 한 번에 몇 노드까지 받을 수 있나 — 호출 비용

**결론: MCP는 노드 하나당 한 호출이고 배치가 없다. REST는 한 요청에 여러 노드를 넣는다.
이 차이가 REST 토큰을 setup 항목으로 넣을지 말지를 가르는 유일한 이유다.**

### MCP 호출 수 산정

이미지 도구(`get_screenshot`, `download_assets`) 둘 다 `nodeId`가 **단수 필수**다.
복수 id를 받는 파라미터가 없다. 따라서:

```
대장 작성 (1회성 — 시안이 바뀔 때만 재실행)
  페이지 열거              : get_metadata(fileKey)              → 1회
  페이지별 프레임+서브트리 : get_metadata(fileKey, pageId) × P  → P회
                             (P = 화면이 들어있는 페이지 수)
  합계                     : 1 + P회 ≒ 한 자릿수

QA 실행 (매 실행)
  섹션 크롭                : get_screenshot × (N × S)
  화면 전체 참고샷(선택)   : get_screenshot × N
                             N = 화면 수, S = 화면당 섹션 수
```

화면 40개 × 섹션 4개면 **섹션 크롭에만 160회 호출**이다.
여기에 스테이징 브라우저 스크린샷 40장, VLM 판정, 노션 행 생성이 얹힌다.

### REST 호출 수 산정

`GET /v1/images/<file-key>?ids=<a>,<b>,<c>,…` 는 **한 요청에 여러 노드를 렌더한다.**
같은 파일의 섹션 160개를 몇 개의 요청으로 나눠 담을 수 있다.

다만 **한 요청에 넣을 수 있는 id 개수의 상한은 문서에 없다.**
OpenAPI 명세에 `maxItems`가 없고, 산문 문서에도 "최대 N개" 문구가 없다.
간접 신호만 있다 — 에러 문서에 500이 "Commonly happens with large image render
requests that time out the server"로 적혀 있다.
**즉 배치 크기는 문서화된 상수가 아니라 실측으로 정할 튜닝 노브다.** `미검증`

### 레이트 리밋 — 여기가 진짜 제약이다

피그마는 이제 **구체적인 숫자를 공개한다** (`/docs/rest-api/rate-limits/`).
리밋은 좌석 종류 × 엔드포인트 티어 × 플랜의 조합으로 정해지고, 누수 버킷 알고리즘이다.

**우리가 쓰려는 세 엔드포인트 — `GET /v1/files`, `GET /v1/files/:key/nodes`,
`GET /v1/images` — 는 전부 가장 빡빡한 Tier 1에 들어 있다.**

| 좌석 | Starter | Professional | Organization |
|---|---|---|---|
| View, Collab | 월 6회 | 월 6회 | 월 6회 |
| Dev, Full | **분당 10회** | **분당 15회** | **분당 20회** |

이 숫자가 설계에 미치는 영향은 결정적이다.

- **`/v1/images`와 `/v1/files`는 같은 Tier 1 버킷을 공유한다.** 이미지용 별도 예산이 없다.
- Full 좌석 Professional 플랜 기준 **분당 15회**. 배치 없이 노드당 한 요청으로
  160개를 뽑으면 **최소 11분**이 걸린다. 배치를 쓰면 몇 요청으로 끝난다.
  **배치가 선택이 아니라 필수인 이유가 이것이다.**
- 반면 `GET /v1/files/:key/versions`와 이미지 fills는 **Tier 2**(Full 좌석 기준
  분당 50~100회), `GET /v1/files/:key/meta`는 **Tier 3**(분당 100~150회)로 훨씬 넉넉하다.
  **변경 감지 폴링은 반드시 Tier 3의 `/meta`로 해야 한다** — Tier 1을 태우면 안 된다.
- 429 응답에는 `Retry-After`(초), `X-Figma-Plan-Tier`, `X-Figma-Rate-Limit-Type`
  헤더가 붙는다. 재시도 로직이 이걸 읽어야 한다.
- 요청당 "가중치"(예: id 개수에 비례하는 비용)는 문서화돼 있지 않다.
  티어당 **평평한 요청 수 카운트**로 보인다 — 이것도 배치가 유리한 이유다.

**MCP 표면의 리밋은 별개이고, 수치를 확인하지 못했다.** `whoami` 응답이
`file://figma/docs/rate-limits-access.md` 리소스를 함께 실어 보내고,
도구 설명도 "You MUST use this tool if you are experiencing file access/permission
issues or **are being rate limited by the Figma MCP**"라고 적어 리밋의 존재를 확인해준다.
구체적 수치는 그 MCP 리소스를 읽어야 알 수 있는데 파일시스템에는 없었다. `미검증`
**프로토타입 착수 전에 반드시 읽어야 한다** — MCP만으로 160회를 때리는 v1 설계가
성립하는지가 여기 달려 있다.

---

## 5. 시안이 바뀌었는지 알 수 있는 버전·수정시각 값

**결론: 파일 단위로는 얻을 수 있고 REST에만 있다. 화면(프레임) 단위로는 얻을 수 없다.**

이번 리서치에서 가장 중요한 두 발견이 여기 있다.

### MCP에는 아예 없다

`get_metadata`가 주는 것은 명시적으로 "node IDs, layer types, names, positions and
sizes"뿐이다. 타임스탬프도 버전도 없다. `get_screenshot`, `download_assets`,
`get_design_context` 어디에도 버전 필드가 없다.

`use_figma`로 플러그인 API를 직접 때리는 우회로도 막혀 있다.
플러그인 API 타입 정의(`plugin-api-standalone.d.ts`)를 `lastModified`, `versionId`,
`getFileVersion`으로 훑었으나 **하나도 없다.** 있는 것은 `figma.fileKey`(파일 키 읽기)와
`figma.saveVersionHistoryAsync(title, description?)`(버전을 **쓰는** 쪽)뿐이다.
읽는 API가 없다.

### REST에는 파일 단위로 있다

`GET /v1/files/<file-key>` 응답 최상위에 둘 다 있고, 명세의 설명이 정확히 우리 용도다.

- **`lastModified`** (ISO 8601, UTC) — "The UTC ISO 8601 time at which the file was last modified."
- **`version`** (문자열) — "The version number of the file. This number is incremented
  when a file is modified and **can be used to check if the file has changed between requests.**"

여기에 **`GET /v1/files/<file-key>/meta`** 가 있고 이게 **Tier 3**이라
폴링 용도로 가장 싸다. 변경 감지는 이 엔드포인트로 해야 한다.

`GET /v1/files/<file-key>/versions`는 명명된 버전 이력을 준다
(`id`, `created_at`, `label`, `description`, `user`, 페이지네이션 지원, 기본 30개·최대 50개).
디자이너가 이름 붙인 버전만 나오므로 일상적 편집 감지에는 쓸 수 없다. Tier 2.

### 화면(프레임) 단위 변경 감지는 불가능하다

**이게 내 초안의 가정이 깨진 지점이고, 설계에 직접 영향을 준다.**

`GET /v1/files/<file-key>/nodes?ids=...` 응답을 확인한 결과,
`lastModified`는 **최상위에 딱 한 번, 파일 전체 것으로만** 온다.
명세의 문장이 명확하다 — "The `name`, `lastModified`, `thumbnailUrl`, `editorType`,
and `version` attributes are all metadata of **the specified file**."
`nodes` 맵의 각 항목은 `document`(노드 트리), `components`, `componentSets`,
`schemaVersion`, `styles`를 담을 뿐 **자체 타임스탬프가 없다.**

즉 **"40개 화면 중 3개만 바뀌었으니 그 3개만 다시 뽑자"는 피그마가 직접 지원하지 않는다.**

우회로는 하나뿐이다 — `depth`를 준 노드 조회 결과(또는 `get_metadata`의 XML)를
**구조 지문**으로 해싱해 직전 실행과 비교하는 것이다. 그런데 그 지문을 얻으려면
어차피 Tier 1 호출을 태워야 하므로, 절약되는 건 이미지 렌더 비용뿐이다.
**v1에서는 하지 말 것.** 파일이 바뀌었으면 전부 다시 뽑는 게 훨씬 싸고 단순하다.

### 웹훅

피그마 Webhooks V2에 **`FILE_UPDATE`** 이벤트가 있다.
다만 트리거 조건이 "**Triggers within 30 minutes of editing inactivity in a file**"이라
실시간이 아니고, 페이로드에 노드 단위 정보가 없다(`file_key`, `file_name`, `timestamp` 등).
사람이 슬래시 커맨드로 트리거하는 이번 스코프(맵 #1 제약 12)에서는 불필요하다.
나중에 배포 훅 자동으로 승격할 때 다시 볼 값이다.

### 인증과 스코프 — REST 토큰을 붙인다면

- 개인 액세스 토큰은 **`X-Figma-Token` 헤더**로 보낸다. OAuth는 `Authorization: Bearer`.
- 필요한 스코프는 세분화돼 있다. `GET /v1/files`, `/nodes`, `/images`는
  **`file_content:read`**, `/versions`는 **`file_versions:read`**,
  `/meta`는 **`file_metadata:read`**. 넓은 `files:read`도 아직 통하지만
  문서가 **deprecated**로 표시하고 세분 스코프 사용을 권한다.
- **"링크 있는 사람 누구나" 공개 파일이라도 토큰 없이 읽는 경로는 문서에 없다.**
  OpenAPI 명세상 모든 파일 엔드포인트가 인증을 요구한다. `미검증` — 익명 접근이
  불가능하다는 명시적 문장을 찾지는 못했고, 다만 가능하다는 문서도 없다.

---

## 6. 결론 — 대장 한 줄이 담아야 할 피그마 식별자

**한 줄 = 화면 하나.** 섹션은 그 줄 안의 리스트다.
아래가 "나중에 이 화면의 섹션 이미지를 다시 뽑을 수 있는" 최소 집합이다.

| 칸 | 값 | 왜 필요한가 |
|---|---|---|
| `figma_file_key` | `<file-key>` | 모든 MCP·REST 호출의 첫 인자. 브랜치 시안이면 **브랜치 키를 여기 넣는다** |
| `figma_page_id` | `<node-id>` (예: `0:1`) | 프레임을 다시 찾을 때의 진입점. 프레임 id가 깨져도 페이지에서 이름으로 재탐색할 수 있는 복구 경로 |
| `figma_frame_id` | `<node-id>` (콜론 형태) | 화면 전체 크롭과 서브트리 조회의 대상 |
| `figma_frame_name` | 레이어 이름 | **id는 언젠가 깨진다.** 디자이너가 프레임을 다시 만들면 새 id가 붙는다. 이름은 사람이 읽고 고칠 수 있는 앵커이고, 대장은 사람이 검수하는 물건이다 |
| `sections[]` | 아래 3칸의 리스트 | 판정 단위 |
| └ `section_node_id` | `<node-id>` (콜론 형태) | 크롭 대상. **인스턴스 내부 노드(`I…;…`)는 금지** — `get_screenshot` 정규식이 거부한다 |
| └ `section_name` | 레이어 이름 | 지문 키 `qa-key: <화면>/<섹션>/<카테고리>`의 두 번째 조각. **노션 중복 방지가 이 값에 직접 의존한다** |
| └ `section_order` | 정수 | 화면 안 위아래 순서. 스테이징 스크린샷의 같은 구획과 짝지을 때 쓴다 |

**파일 단위 값은 줄이 아니라 대장 머리말에 둔다.** 5번에서 확인했듯
`version`과 `lastModified`는 파일 하나에 하나뿐이고 프레임마다 다르지 않다.
줄마다 복사해두면 40벌의 같은 값이 생기고, 그중 일부만 갱신되는 순간 거짓말을 시작한다.

```
[대장 머리말]
  figma_file_key    : <file-key>
  figma_version     : <version>        # REST 토큰이 있을 때만. 없으면 비워둔다
  figma_last_modified: <iso8601>       # 위와 같음
  fetched_at        : <iso8601>        # 크롭을 마지막으로 뽑은 시각
```

**대장에 넣지 말아야 할 것**도 분명히 해둔다.

- **이미지 URL은 넣지 않는다.** MCP URL은 수명이 짧고 REST URL도 30일이면 만료된다.
  대장은 오래 사는 물건이고 URL은 오래 못 산다. 대장에는 **id만** 담고,
  URL은 실행 때마다 새로 받는다.
- **배율·포맷은 넣지 않는다.** 화면마다 다를 이유가 없다. setup 설정으로 뺀다.
  (뷰포트 390이 setup 값인 것과 같은 논리 — 맵 #1 제약 9)
- **좌표(x/y/w/h)는 넣지 않는다.** 크롭은 노드 id로 뽑지 좌표로 뽑지 않는다.
  좌표는 시안이 바뀌면 즉시 썩는다.

그리고 피그마 식별자는 아니지만 같은 줄에 반드시 붙어야 하는 것 —
맵 #1 제약 5·13·14가 요구하는 **라우트**와 **자연어 도달 스텝**,
그리고 경로를 못 찾았을 때의 **`도달: 미상`** 표시다.
피그마 쪽 칸이 다 차 있어도 도달 경로가 없으면 그 줄은 실행 불가이고,
조용히 빠지는 대신 "미커버"로 세어져야 한다.

### 네 문장 요약

프레임 열거와 섹션 트리는 `get_metadata` 하나로, 파일 키만 있으면, 토큰 없이,
한 자릿수 호출로 끝난다. 섹션 크롭은 `get_screenshot`이 노드당 한 장씩 뽑아주는데
**배치가 안 되므로 화면 수 × 섹션 수만큼 호출이 든다.**
REST로 내려가면 `/v1/images?ids=…` 한 요청으로 여러 섹션을 받을 수 있지만
그 엔드포인트는 **Tier 1 · 분당 10~20회**라는 빡빡한 리밋에 묶여 있어
배치가 선택이 아니라 필수가 된다. 변경 감지에 쓸 `version`·`lastModified`는
**MCP에 없고 REST에만, 그것도 파일 단위로만** 있으므로,
"바뀐 화면만 다시 뽑기"는 원리적으로 불가능하고 v1은 파일이 바뀌면 전부 다시 뽑아야 한다.

---

## 다음에 확인해야 할 것 (프로토타입 착수 전)

1. **MCP 레이트 리밋 수치** — `file://figma/docs/rate-limits-access.md` 리소스를 읽는다.
   REST Tier 1이 분당 10~20회인 것을 보면, MCP도 넉넉하지 않을 가능성이 크다.
   160회 배치가 통과하는지가 v1 설계의 전제다.
2. **`maxDimension`과 세로로 긴 모바일 화면** — 390×3000 프레임을 기본 1024로 받으면
   얼마나 뭉개지는지, VLM이 그걸로 판정 가능한지.
3. **인스턴스 내부 노드 스크린샷 거부 여부** — 실제 컴포넌트 인스턴스 섹션으로 때려본다.
4. **`get_metadata` 응답 크기** — 실제 화면 프레임 하나의 서브트리가 몇 토큰인지.
   이게 대장 작성 단계의 컨텍스트 한계를 정한다.
5. **REST `/v1/images`의 실용적 배치 크기** — 문서에 상한이 없으므로 실측한다.
   500(타임아웃)이 나기 시작하는 지점을 찾아 그 절반쯤을 쓴다.
