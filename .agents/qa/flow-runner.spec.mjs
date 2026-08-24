// 대장 flows: 컴파일 산출(flows.json)을 실행한다. 검사 1개 = 테스트 1개.
// 의미론은 MCP 경로·시각 회귀 하네스의 Interaction 과 같다:
//   조작 3종 clickText(정확 일치, 없으면 접두 일치 유일 요소) · fillPlaceholder · scrollToText
//   expect 5종 url(정규식) · text · no_text · attr · back — 위에서 아래로, 첫 실패에서 멈춘다.
// 판정만 한다 — 행 생성·리포트는 scan 이 결과 JSON 을 읽어서 한다.
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";

// 대상 레포의 @playwright/test 를 빌린다 — 이 파일은 플러그인 디렉터리에 살아서
// 파일 위치 기준 ESM 해석이 안 닿는다. 기준 루트는 config 가 env 로 물려준다.
const require = createRequire(join(process.env.QA_TARGET_ROOT || process.cwd(), "package.json"));
const { expect, test } = require("@playwright/test");

const { flows } = JSON.parse(readFileSync(process.env.QA_FLOWS, "utf8"));

const settle = (page) => page.waitForLoadState("networkidle", { timeout: 5_000 }).catch(() => {});

async function clickText(page, text, forbidden) {
  if (forbidden.includes(text)) throw new Error(`forbidden 문구라 클릭 거부: ${text}`);
  const exact = page.getByText(text, { exact: true }).first();
  if ((await exact.count()) > 0) return exact.click();
  // 접두 일치 — 탭 라벨에 카운트가 붙는 실물("종료 0"). 유일할 때만 누른다.
  const handle = await page.evaluateHandle((t) => {
    const leaves = [...document.querySelectorAll("*")].filter(
      (e) => e.children.length === 0 && e.textContent.trim().startsWith(t),
    );
    return leaves.length === 1 ? leaves[0] : null;
  }, text);
  const el = handle.asElement();
  if (!el) throw new Error(`clickText 대상이 없거나 모호함: ${text}`);
  await el.click();
}

async function runStep(page, step, forbidden) {
  if (step.clickText) await clickText(page, step.clickText, forbidden);
  else if (step.fillPlaceholder)
    await page.getByPlaceholder(step.fillPlaceholder.placeholder).fill(String(step.fillPlaceholder.value));
  else if (step.scrollToText) await page.getByText(step.scrollToText).first().scrollIntoViewIfNeeded();
  else throw new Error(`모르는 스텝: ${JSON.stringify(step)}`);
  await settle(page);
}

async function runExpect(page, ex, i) {
  const tag = `expect[${i}] ${JSON.stringify(ex)}`;
  if (ex.url) {
    await expect.poll(() => page.url(), { message: tag }).toMatch(new RegExp(ex.url));
  } else if (ex.text) {
    await expect.poll(() => page.locator("body").innerText(), { message: tag }).toContain(ex.text);
  } else if (ex.no_text) {
    await settle(page); // 부재 단언은 화면이 앉은 뒤에만 뜻이 있다
    expect(await page.locator("body").innerText(), tag).not.toContain(ex.no_text);
  } else if (ex.attr) {
    // 문구 정확 일치 리프에서 위로 걸어 올라가 그 속성을 가진 첫 요소의 값
    const value = await page.evaluate(({ text, name }) => {
      const leaves = [...document.querySelectorAll("*")].filter(
        (e) => e.children.length === 0 && e.textContent.trim() === text,
      );
      for (const leaf of leaves)
        for (let n = leaf; n; n = n.parentElement) if (n.hasAttribute(name)) return n.getAttribute(name);
      return null;
    }, { text: ex.attr.text, name: ex.attr.name });
    expect(value, tag).toBe(ex.attr.value);
  } else if (ex.back) {
    await page.goBack();
    await settle(page);
  } else {
    throw new Error(`모르는 expect: ${JSON.stringify(ex)}`);
  }
}

for (const f of flows) {
  test(`${f.key} [${f.confidence}]`, async ({ page }) => {
    await page.goto(f.path);
    await settle(page);
    for (const step of [...f.before, ...f.steps]) await runStep(page, step, f.forbidden);
    for (let i = 0; i < f.expect.length; i++) await runExpect(page, f.expect[i], i);
  });
}
