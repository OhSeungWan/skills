# 브라우저 조작·스크린샷 수단 비교

리서치 티켓: [#2](https://github.com/OhSeungWan/skills/issues/2) (맵 [#1](https://github.com/OhSeungWan/skills/issues/1))

## 무엇을 정하려는 것인가

`design-qa` 스킬은 화면 대장에 적힌 **자연어 스텝**("위자드 2스텝까지 진행 → TV 카드 선택")을 읽어 스테이징 앱을 그 지점까지 몰고 간 다음, 판정 단위인 **섹션만 크롭한 이미지**를 뷰포트 390에서 남겨야 한다. 그 이미지를 피그마 섹션 이미지와 나란히 놓고 VLM이 서술로 판정한다.

즉 이 티켓이 고르는 것은 "브라우저를 어떻게 여느냐"가 아니라 **자연어 스텝 → 조작 → 섹션 크롭 이미지**라는 파이프라인 전체를 무엇이 감당하느냐다. 판정 기준 다섯 개는 맵의 제약 4·8·9·13에서 그대로 내려온 것이라 하나라도 못 하면 그 후보는 스킬을 못 만든다.

1. 자연어 스텝을 셀렉터 없이 실행할 수 있나
2. 뷰포트를 390으로 고정할 수 있나
3. 전체 화면 말고 특정 영역만 크롭해 저장할 수 있나
4. 스테이징 로그인 세션을 유지할 수 있나
5. 헤드리스로 배치 실행되나, 사람 화면을 점유하나

## 사전 확인: 대상 레포에 Playwright가 이미 있나

티켓이 "대상 레포에 이미 있는지부터 확인"하라고 한 것부터 답한다. 로컬에 받아 둔 대상 프런트엔드 레포(Next.js 앱) 체크아웃을 직접 열어 확인했고, 결론은 **Playwright가 없다**는 것이다.

`package.json`에 `playwright`·`@playwright/test`·`playwright-core` 어느 것도 없고, `playwright.config.*` 파일도 없다. 대신 **Cypress 14**가 devDependency로 들어 있고 `cypress.config.ts` 하나에 스펙 파일 6개가 있다. 그 설정은 `experimentalStudio`(클릭을 녹화해 테스트로 만드는 기능)만 켜 둔 상태이고 `baseUrl`도 `viewportWidth`도 지정하지 않는다. Puppeteer·Selenium·Storybook test-runner·Chromatic·Percy 같은 다른 브라우저 자동화 물건도 없다.

이게 판정에 주는 함의는 두 가지다.

첫째, **"이미 있으니까 그걸 쓴다"는 지름길이 없다.** 어느 후보를 골라도 새로 들여오는 것이고, 따라서 후보 비교는 기존 자산에 얹히는지가 아니라 순수하게 다섯 기준으로만 해야 한다.

둘째, **Cypress는 후보가 아니다.** 티켓이 후보로 올리지 않았거니와, 도메인이 `cy.*` 체이닝 코드로 고정돼 있어 기준 1(자연어 스텝)에서 Playwright 라이브러리와 같은 이유로 떨어진다. 더 중요한 건 그게 **살아 있는 하니스가 아니라 방치된 스타터**라는 점이다. 스크립트는 `cypress open` 하나뿐이라 CI가 부르는 경로가 없고, 관련 파일이 2025년 초 커밋 이후 손대지 않은 채로 있다. "팀이 이미 쓰는 도구에 맞춘다"는 논거가 서지 않는다.

다만 이건 새 도구를 고르는 쪽에도 비용을 지운다 — 무엇을 들이든 **잠자는 브라우저 자동화 의존성 하나가 이미 있는 레포에 두 번째를 얹는 것**이다. 결론에서 이 값을 치를 만한지 따로 짚는다.

## 후보 1 — Playwright 라이브러리 (`@playwright/test`)

**자연어 스텝 (기준 1) — 못 한다, 코드를 짜야 한다.** Playwright에는 `page.act("TV 카드를 눌러")` 같은 자연어 API가 없다. 공식 문서에 있는 AI 관련 물건은 [Test Agents](https://playwright.dev/docs/test-agents)뿐인데, 이건 planner·generator·healer 세 개의 **에이전트 정의 마크다운 파일**을 내 코딩 에이전트에 설치해 주는 도구다. 자체 모델이 도는 게 아니고, 게다가 그 정의 파일들이 브라우저를 만질 때 쓰는 도구 목록이 `browser_click` · `browser_snapshot` 같은 **Playwright MCP의 도구 표면**이다. 다시 말해 Playwright 진영이 공식적으로 미는 자연어 경로 자체가 MCP를 거친다.

라이브러리를 직접 쓰면 스텝마다 사람이 셀렉터를 적어야 하는데, 맵 제약 13이 자연어 스텝을 못 박은 이유가 정확히 이것이다 — 대장은 사람이 검수·수정하는 물건이라 셀렉터가 박혀 있으면 못 고치고, 프런트 리팩터 한 번에 통째로 썩는다.

**뷰포트 (기준 2) — 된다.** `use: { viewport: { width: 390, height: 844 } }` 또는 `browser.newContext({ viewport })`, 런타임이면 `page.setViewportSize()`. 문서는 `devices` 스프레드 **뒤에** `viewport`를 써야 한다고 명시한다 — 디바이스 서술자가 자기 뷰포트를 이미 들고 있기 때문이다 ([emulation](https://playwright.dev/docs/emulation)).

**크롭 (기준 3) — 가장 강하다.** 두 갈래가 다 있다.

- `locator.screenshot()` — 그 엘리먼트의 바운딩 박스로 잘라 찍는다. 액셔너빌리티 체크를 기다린 뒤 **스크롤해서 화면에 넣고** 찍는다 ([class-locator](https://playwright.dev/docs/api/class-locator#locator-screenshot)).
- `page.screenshot({ clip: { x, y, width, height } })` — 임의 사각형. 섹션이 DOM 노드 하나에 대응하지 않을 때의 유일한 길이다 ([class-page](https://playwright.dev/docs/api/class-page#page-screenshot)).

여기에 디자인 QA에 실제로 필요한 손잡이가 붙어 있다. `animations: 'disabled'`(기본값은 `'allow'`라 명시적으로 켜야 한다), 흔들리는 요소를 덮는 `mask`, 그리고 **`style`** — 스크린샷 찍는 동안만 적용할 CSS를 문자열로 넣는 옵션이다. 스티키 헤더가 섹션 위에 겹쳐 찍히는 문제를 이걸로 없앤다. `locator.screenshot()` 문서가 "다른 요소에 덮여 있으면 스크린샷에도 안 보인다"고 명시하므로 이건 가정이 아니라 확정된 함정이다.

주의할 함정 하나: `page.screenshot`/`locator.screenshot`의 `scale` 기본값은 `'device'`다. iPhone 14 서술자(390×664, deviceScaleFactor 3)를 그대로 쓰면 **1170px 폭 PNG**가 나온다. 피그마와 1:1로 대조하려면 `scale: 'css'`를 주거나 `deviceScaleFactor: 1`로 맞춰야 한다 ([screenshot-option-scale](https://playwright.dev/docs/api/class-page#page-screenshot-option-scale)).

**세션 (기준 4) — 된다.** `context.storageState({ path })`로 저장하고 `newContext({ storageState })` 또는 `use: { storageState }`로 재사용한다 ([auth](https://playwright.dev/docs/auth)). 저장 범위는 쿠키·로컬스토리지·IndexedDB·WebAuthn 자격증명인데, **IndexedDB는 옵트인**이다 — API 레퍼런스는 `indexedDB: true`를 넘겨야 한다고 적고 있는 반면 auth 가이드는 그냥 포함된다고 적어 둬서 둘이 어긋난다. 스테이징 앱이 토큰을 IndexedDB에 두는 구조면 플래그를 명시적으로 켜야 한다.

**헤드리스 (기준 5) — 기본이 헤드리스다.** `headless` 기본값이 `true`이고, 헤드로 보고 싶으면 `--headed`를 준다 ([test-cli](https://playwright.dev/docs/test-cli)). 사람 화면을 점유하지 않는다. 픽셀 충실도를 생각하면 `channel: 'chromium'`(진짜 Chrome 헤드리스)이 옛 headless shell보다 낫다 ([browsers](https://playwright.dev/docs/browsers)).

**정리** — 기준 2·3·4·5를 전부, 그것도 가장 잘 만족한다. 유일하게 못 하는 게 기준 1이고, 그게 이 맵의 핵심 제약이다.

## 후보 2 — Playwright MCP

[microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp)의 README와, 실제 도구 소스가 옮겨 간 [playwright 모노레포의 `packages/playwright-core/src/tools/backend`](https://github.com/microsoft/playwright/tree/main/packages/playwright-core/src/tools/mcp)를 읽고 판정했다.

**자연어 스텝 (기준 1) — 된다. 셀렉터를 짤 필요가 없다.** README가 내세우는 설계가 "픽셀 입력이 아니라 **접근성 트리**를 쓴다, 비전 모델이 필요 없다, 결정론적이다"이다. 동작 방식은 이렇다.

```
- textbox "What needs to be done?" [ref=e5]
- checkbox "Toggle Todo" [ref=e10]
```

`browser_snapshot`이 위 같은 트리를 뱉으면 모델은 `ref=e5`를 집어 조작한다. 모든 조작 도구가 `element`(사람이 읽는 설명)와 `target`(스냅샷 ref **또는** 셀렉터) 쌍을 받는데, ref로 충분하므로 셀렉터는 대안이지 필수가 아니다. 트리 전체를 매번 받기 부담스러우면 `browser_find`로 텍스트·정규식 검색만 해서 ref를 얻을 수도 있다.

"위자드 2스텝까지 진행 → TV 카드 선택"은 그래서 `snapshot → 접근 가능한 이름에 'TV'가 든 노드 찾기 → 그 ref를 click → 다시 snapshot` 루프로 그대로 풀린다. 자연어 스텝이 코드로 굳지 않고 실행 시점에 트리를 보고 해석된다.

**뷰포트 (기준 2) — 된다.** CLI 플래그 `--viewport-size=390x844`가 결정론적으로 가장 안전하다. 도구 `browser_resize`도 있고 `--device "iPhone 15"` 같은 서술자도 있지만, 서술자 폭은 릴리스마다 바뀐다 — iPhone 14는 390인데 iPhone 15는 393, iPhone 17은 402다. `--mobile`은 Chromium에서 Pixel 10(360)이라 390이 아니다. **390을 못 박아야 하니 `--viewport-size`를 쓴다.**

**크롭 (기준 3) — 엘리먼트 단위는 되고, 임의 사각형은 안 된다.** 이게 이 티켓에서 가장 중요한 확인이었다. `browser_take_screenshot`의 스키마는 `element` / `target` / `type` / `filename` / `fullPage` / `scale`이고, 핸들러가 이렇게 갈라진다.

```ts
if (params.fullPage && params.target)
  throw new Error('fullPage cannot be used with element screenshots.');
const target = params.target ? await tab.targetLocator({ ... }) : null;
const data = target ? await target.locator.screenshot(options) : await tab.page.screenshot(options);
```

즉 `target`에 스냅샷 ref를 주면 **`locator.screenshot()`으로 그대로 내려가** 그 노드만 잘라 찍는다. 반대로 `clip` 파라미터는 스키마에 아예 없다. 여기서 `scale` 기본값이 라이브러리와 달리 `'css'`라, 피그마 대조에 필요한 1:1 CSS 픽셀이 기본으로 나온다는 점은 오히려 유리하다.

`filename`을 반드시 넘겨야 한다. 소스를 보면 파일은 항상 원본 해상도로 디스크에 쓰지만, `filename`을 생략하면 모델에게 인라인 이미지까지 돌려주면서 1568px/1.15MP로 축소한다 — 컨텍스트만 태우고 얻는 게 없다.

**세션 (기준 4) — 된다, 두 방식으로.** 기본이 **영속 프로필**이라 한 번 로그인해 두면 그 상태가 디스크에 남는다(`--user-data-dir`로 위치 지정 가능, 워크스페이스 해시로 프로젝트마다 분리). 재현 가능한 배치를 원하면 `--isolated --storage-state=<파일>`로 미리 만들어 둔 상태를 주입한다. 다만 영속 프로필은 **한 번에 한 브라우저 인스턴스만** 쓸 수 있어, 같은 워크스페이스에서 클라이언트를 병렬로 띄우면 충돌한다.

**헤드리스 (기준 5) — 되지만 기본이 헤드다.** `--headless`를 안 주면 사람 화면에 진짜 창이 뜬다. 배치로 도는 QA 스킬은 `--headless`를 반드시 붙여야 한다.

**정리** — 다섯 기준을 다 통과한다. 다만 크롭이 "DOM 노드 하나"에 묶인다는 천장이 있고, 라이브러리에 있던 `style`·`mask`·`animations` 손잡이가 `browser_take_screenshot`에는 노출돼 있지 않다. 스티키 헤더가 섹션 위에 겹치면 그대로 찍힌다.

## 후보 3 — Orca 임베디드 브라우저 (`orca-cli`)

`orca skills get orca-cli`가 뱉는 버전 일치 가이드와, 로컬 바이너리(`ORCA_APP_VERSION` 1.4.x)의 `--help` 출력을 직접 읽고 판정했다.

**자연어 스텝 (기준 1) — 된다.** 구조가 Playwright MCP와 같은 스냅샷-조작-재스냅샷 루프다. `orca snapshot`이 `@e1`, `@e2` 같은 ref를 붙여 접근성 트리를 주고, `orca click --element @e3`으로 조작한다. `orca find --locator role|text|label --value <v>`로 이름 기반 탐색도 된다. 셀렉터를 미리 짤 필요는 없다.

**뷰포트 (기준 2) — 반만 된다.** `orca set device --name "iPhone 12"`로 디바이스 에뮬레이션은 되지만, **폭을 숫자로 지정하는 명령이 없다.** 390은 iPhone 12/13/14 서술자에 얹혀 나오는 값이지 내가 못 박는 값이 아니다. 맵 제약 9가 "뷰포트는 390 하나, setup에서 변경 가능"이라고 했는데, 사람이 setup에서 375나 412를 넣고 싶어지면 대응할 방법이 없다.

**크롭 (기준 3) — 안 된다. 여기서 탈락한다.** 스크린샷 명령은 딱 둘이고, `--help`가 받는 인자를 그대로 보여 준다.

```
orca screenshot      [--format <png|jpeg>] [--worktree <selector>] [--json]
   Capture a viewport screenshot of the active browser tab
orca full-screenshot [--format <png|jpeg>] [--worktree <selector>] [--json]
   Capture a full-page screenshot (beyond viewport)
```

영역도, 엘리먼트도 받지 않는다. **뷰포트 한 장 아니면 전체 페이지 한 장뿐이다.** 맵 제약 8이 "판정 단위는 섹션 크롭, 화면 전체 1장을 주면 VLM이 '대체로 비슷함'으로 끝낸다"고 못 박은 바로 그 실패 모드에 정면으로 걸린다. `orca eval`로 `getBoundingClientRect()`를 얻어 전체 스크린샷을 사후에 잘라내는 우회는 가능하지만, 그건 이미지 처리 단계를 하나 더 만들어 붙이는 것이지 이 도구가 크롭을 한다는 뜻이 아니다.

**세션 (기준 4) — 된다.** `orca tab profile create/set/clone`으로 브라우저 세션 프로필을 만들고 탭에 물릴 수 있다(`--scope isolated|imported`). 로그인 상태 유지는 문제없다.

**기준 5 — 사람 화면을 점유한다.** 이름 그대로 Orca 앱 **안에 임베디드된** 브라우저 탭이다. `orca tab create`에 헤드리스 플래그가 없고, 탭은 워크트리의 UI 페인으로 열린다. 헤드리스 옵션 자체가 이 표면에 존재하지 않는다.

**정리** — 기준 3에서 탈락한다. 기준 2·5도 약하다. 이건 Orca가 못 만든 게 아니라 용도가 다른 것이다 — 사람이 보면서 같이 쓰는 브라우저지, 배치로 증거 이미지를 뽑는 파이프라인이 아니다.

## 후보 4 — `computer-use` CLI

`orca skills get computer-use`가 뱉는 가이드와 `orca computer --help`를 읽고 판정했다.

이건 웹 자동화 도구가 아니라 **데스크톱 앱 자동화** 도구다. 접근성 트리로 앱 창을 읽고 클릭·타이핑·스크롤·드래그를 넣는다. 가이드 본문이 "웹사이트가 대상이면 그 페이지를 담고 있는 **데스크톱 브라우저 앱/창**을 조작하라"고 적고 있고, 에러 코드 `app_not_found` 설명에도 "Gmail 같은 웹앱이 대상이면 데스크톱 브라우저 앱을 고르라, `--app Gmail`로 재시도하지 말라 — 앱 셀렉터는 데스크톱 앱이지 웹사이트 이름이 아니다"라고 명시돼 있다.

**자연어 스텝 (기준 1) — 형태상 된다.** `get-app-state`가 엘리먼트 인덱스가 붙은 접근성 트리를 주고 `click --element-index 42`로 조작한다. 다만 가이드가 인덱스는 "수명이 짧고 지연·내비게이션·포커스 변경·스크롤·재렌더 뒤에 무효화된다"고 경고한다. 위자드처럼 매 스텝 리렌더되는 화면에서는 매번 상태를 다시 받아야 한다.

**뷰포트 (기준 2) — 못 한다.** 뷰포트라는 개념이 없다. 브라우저 **창** 크기이지 CSS 뷰포트가 아니고, 390을 지정하는 명령이 없다. 창을 손으로 맞춘다 해도 브라우저 크롬(주소창·탭바)이 차지하는 만큼을 빼야 하고 그게 OS·브라우저·확대율마다 다르다. 재현 가능한 390이 나오지 않는다.

**크롭 (기준 3) — 못 한다.** 스크린샷은 `get-app-state`가 트리와 함께 돌려주는 **창 단위 캡처** 하나뿐이고, 별도의 크롭 인자가 없다. `--no-screenshot`으로 끄는 것만 된다.

**세션 (기준 4) — 된다.** 사람이 쓰던 실제 브라우저를 그대로 조작하므로 로그인 세션은 당연히 유지된다. 이게 이 도구의 유일한 강점이다.

**기준 5 — 사람 화면을 완전히 점유한다.** 헤드리스가 원리적으로 불가능하다. 게다가 가이드가 창이 가려지면 픽셀이 오염될 수 있으니 `--restore-window`로 앞으로 끌어내라고 안내한다 — 즉 **배치로 돌리면 사람이 쓰던 창을 뺏는다.** 캡처가 실패하는 조건으로 "숨김·최소화·화면 밖"을 든다는 건, 이 도구가 실제로 화면에 보이는 픽셀을 찍는다는 뜻이다.

**정리** — 기준 2·3·5에서 탈락한다. 목적 자체가 다른 도구라 후보로 남겨 둘 이유가 없다.

## 비교표

| 기준 | Playwright | Playwright MCP | Orca 임베디드 브라우저 | computer-use CLI |
| --- | --- | --- | --- | --- |
| 1. 자연어 스텝, 셀렉터 불필요 | ✗ 코드를 짜야 함 | ✓ 스냅샷 ref 루프 | ✓ 스냅샷 ref 루프 | △ 인덱스가 쉽게 무효화 |
| 2. 뷰포트 390 고정 | ✓ 숫자로 지정 | ✓ `--viewport-size` | △ 디바이스 프리셋뿐 | ✗ 개념 없음 |
| 3. 영역 크롭 저장 | ✓ 엘리먼트 + 임의 사각형 | △ 엘리먼트만 | ✗ 뷰포트/전체뿐 | ✗ 창 전체뿐 |
| 4. 로그인 세션 유지 | ✓ `storageState` | ✓ 영속 프로필 / `--storage-state` | ✓ 탭 프로필 | ✓ 실제 브라우저 |
| 5. 헤드리스 배치 | ✓ 기본 헤드리스 | ✓ `--headless` (기본은 헤드) | ✗ 앱 UI 점유 | ✗ 사람 화면 점유 |

## 결론 — Playwright MCP를 쓴다

**이유는 기준 1과 기준 3을 동시에 만족하는 유일한 후보이기 때문이다.**

기준 3(섹션 크롭)에서 Orca 브라우저와 computer-use가 먼저 떨어진다. 둘 다 화면 한 장밖에 못 준다. 맵 제약 8이 "화면 전체 1장을 주면 VLM이 대체로 비슷함으로 끝낸다"고 이미 판정해 둔 실패 모드라, 여기서 걸리면 스킬이 성립하지 않는다. 우회로 사후 크롭을 붙일 수는 있지만, 그러면 좌표를 얻는 코드·이미지를 자르는 단계를 새로 만드는 것이고 그건 이미 있는 도구를 쓰는 게 아니라 도구를 하나 짓는 것이다.

남은 둘 중에서는 기준 1이 가른다. Playwright 라이브러리는 크롭이 제일 강하지만 스텝마다 셀렉터를 사람이 적어야 한다. 맵 제약 13이 자연어 스텝을 못 박은 이유가 "대장은 사람이 검수·수정하는 물건이라 셀렉터면 못 고치고 리팩터 한 번에 썩는다"였다. 대장을 코드로 만드는 순간 이 목적지의 전제가 무너진다.

Playwright MCP는 접근성 스냅샷의 ref로 조작하므로 자연어 스텝이 실행 시점에 해석되고, 그 **똑같은 ref를 `browser_take_screenshot`의 `target`에 넘겨 그 노드만 잘라 찍을 수 있다.** "TV 카드를 선택하고 그 영역을 찍어라"가 도구 두 번 호출로 끝난다는 뜻이다. 조작과 판정이 같은 좌표계를 쓰는 게 이 후보의 본질적 강점이고, 나머지는 다 부수적이다. 뷰포트는 `--viewport-size=390x844`로 못 박히고, 세션은 영속 프로필이나 `--storage-state`로 유지되고, `--headless`로 사람 화면을 뺏지 않는다. `scale` 기본값이 `'css'`라 피그마와 1:1 대조에 쓸 픽셀이 그냥 나온다.

권고 기동 형태:

```
--headless --viewport-size=390x844 --output-dir=<QA 산출물 디렉터리>
```

캡처는 항상 `filename`을 명시해 원본 해상도 파일만 남기고 인라인 이미지로 컨텍스트를 태우지 않는다.

### 두 번째 의존성 비용은 어떻게 되나

앞에서 짚은 "잠자는 Cypress 위에 두 번째 브라우저 자동화를 얹는 비용"은 **이 선택에 한해 거의 발생하지 않는다.** Playwright MCP는 대상 레포의 devDependency가 아니라 에이전트 쪽에서 MCP 서버로 띄우는 프로세스다. 대상 프런트엔드 레포의 `package.json`·락파일·CI는 그대로다. 맵 제약 15("스킬은 이 레포에 살고, 대상별 설정만 대상 레포 파일로 뺀다")와도 이 편이 맞는다 — 대상 레포에 남는 건 화면 대장과 설정값뿐이다.

반대로 Playwright 라이브러리를 골랐다면 `@playwright/test`와 브라우저 바이너리가 대상 레포에 들어가고, 죽은 Cypress와 산 Playwright가 한 레포에서 나란히 e2e를 자칭하는 상태가 된다. 기준 1에서 이미 떨어진 후보지만, 떨어뜨릴 이유가 하나 더 있는 셈이다.

### 알고 들어가는 천장 두 개

1. **DOM 노드 하나에 대응하지 않는 섹션은 못 자른다.** MCP에는 `clip`이 없다. 피그마 섹션이 여러 형제 노드에 걸쳐 있으면 공통 조상을 `target`으로 잡아 조금 넓게 찍든가, 그 화면만 `@playwright/test` 스크립트로 내려가야 한다. `browser_run_code_unsafe`로 `page.screenshot({ clip })`을 직접 부르는 길도 있지만 문서가 스스로 RCE 등가라고 경고하는 도구다 — 스킬 기본 경로에 둘 물건이 아니다.
2. **스티키 헤더가 섹션 위에 겹쳐 찍힌다.** `locator.screenshot()`의 `style`·`mask`·`animations` 옵션이 `browser_take_screenshot`에는 노출돼 있지 않다. 캡처 직전에 `browser_evaluate`로 헤더를 `position: static`으로 눕히는 우회가 있고, 이건 프로토타입에서 실제로 걸리는지부터 보고 대응하면 된다.

두 천장 모두 "Playwright 라이브러리로 내려간다"는 같은 탈출구를 갖는다. **MCP와 라이브러리는 배타적 선택이 아니라 같은 엔진의 두 표면이다** — 기본 경로를 MCP로 두고, 크롭이 감당 안 되는 화면만 스크립트로 떨어뜨리면 된다. 이게 지금 Orca 브라우저나 computer-use를 골랐을 때는 존재하지 않는 퇴로다.

## 확인하지 못한 것

- 라이브러리에서 `page.screenshot({ fullPage: true, clip })`을 함께 줬을 때의 정확한 우선순위 — 문서에 없다. (MCP 쪽은 명시적으로 에러를 던진다.)
- "헤드리스는 물리 디스플레이가 없어도 된다"는 문장 자체는 공식 문서에서 못 찾았다. MCP 문서의 "디스플레이 없는 시스템에서 헤드**드** 브라우저를 돌릴 때는 HTTP 트랜스포트로 서버를 따로 띄우라"는 안내와 Docker 이미지가 헤드리스 Chromium만 지원한다는 서술로 강하게 함의될 뿐이다.
- Playwright MCP README의 `--caps` 도움말이 `vision, pdf, devtools`만 적고 있는데 본문에는 `config`·`network`·`storage`·`testing` 그룹이 문서화돼 있다. 도움말이 낡은 것으로 보이나 README만으로는 확정하지 못했다.
