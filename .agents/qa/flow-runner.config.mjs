// 플로우 러너 설정 — 대상 레포의 @playwright/test 를 빌려 돈다.
// 실행(대상 레포 루트에서): QA_FLOWS=<flows.json> npx playwright test -c <이 파일 경로>
// 선택 env: QA_OUT(결과 JSON) · QA_RUN_DIR(실패 스크린샷 폴더 — 실행 전에 비워지므로 전용 폴더여야 한다)
import { readFileSync } from "node:fs";
import { dirname, isAbsolute, join } from "node:path";
import { fileURLToPath } from "node:url";

// 이 파일은 플러그인 디렉터리에 살아서 @playwright/test 를 직접 import 못 한다
// (node ESM 은 파일 위치에서 패키지를 찾는다). 설정은 평범한 객체로 충분하다.
// 상대 경로는 config 파일 기준으로 풀리므로(플러그인 디렉터리로 샌다) cwd 기준으로 절대화한다.
const abs = (p) => (isAbsolute(p) ? p : join(process.cwd(), p));

// 테스트 로더·워커는 cwd 가 다를 수 있다 — 여기(메인 프로세스)서 절대화해 env 로 물려준다.
process.env.QA_FLOWS = abs(process.env.QA_FLOWS);
process.env.QA_TARGET_ROOT = process.cwd(); // spec 이 대상 레포의 @playwright/test 를 찾는 기준
const { meta } = JSON.parse(readFileSync(process.env.QA_FLOWS, "utf8"));

export default {
  testDir: dirname(fileURLToPath(import.meta.url)),
  testMatch: "flow-runner.spec.mjs",
  workers: 1, // ponytail: team 존은 공유 환경 — 순차 1워커, 병렬은 존이 버티는 걸 실측한 뒤
  timeout: 30_000,
  // playwright 는 outputDir 를 실행 전에 비운다 — flows.json·results.json 과 같은 폴더에 두면 지워진다.
  outputDir: abs(process.env.QA_RUN_DIR || ".qa/runs/flow-latest/artifacts"),
  reporter: [
    ["list"],
    ["json", { outputFile: abs(process.env.QA_OUT || ".qa/runs/flow-latest/results.json") }],
  ],
  use: {
    baseURL: meta.baseURL,
    storageState: meta.storageState, // 대상 레포 루트 기준 상대 경로
    viewport: meta.viewport,
    permissions: ["local-network-access"], // 없으면 앱이 Network Error 만 그린다 — verify-shot.mjs 와 같은 부여
    screenshot: "only-on-failure",
  },
};
