// design-qa 세션 검증 — Playwright MCP 를 .mcp.json 과 같은 플래그로 띄워
// 화면 한 장을 찍는다. CLI `playwright screenshot` 로는 못 하는 일이다:
// 거기엔 --grant-permissions 가 없어 local-network-access 가 거부되고,
// 앱이 "Network Error" 를 그린다.
//
// 사용법: node verify-shot.mjs <url> <출력 png 경로>
// 세션 파일은 환경변수 PLAYWRIGHT_MCP_STORAGE_STATE 로 받는다.

import { spawn } from 'node:child_process'
import { dirname, basename, resolve } from 'node:path'
import { existsSync } from 'node:fs'
import { tmpdir } from 'node:os'

const url = process.argv[2]
const outPath = resolve(process.argv[3] ?? 'verify-shot.png')
if (!url) {
  console.error('usage: node verify-shot.mjs <url> <out.png>')
  process.exit(2)
}

// .mcp.json 의 args 와 같은 조합으로 맞춘다.
const args = [
  '-y', '@playwright/mcp@0.0.79',
  '--isolated',
  '--headless',
  '--viewport-size=390x844',
  // 콘솔·스냅샷 부산물은 임시 폴더로 보낸다.
  '--output-dir', tmpdir(),
  '--grant-permissions', 'local-network-access',
]

// 스크린샷의 상대 filename 은 --output-dir 이 아니라 서버 프로세스의 cwd 에
// 저장된다. 그래서 cwd 를 출력 폴더로 맞춘다.
const proc = spawn('npx', args, { stdio: ['pipe', 'pipe', 'inherit'], env: process.env, cwd: dirname(outPath) })

let buf = ''
const pending = new Map()
proc.stdout.on('data', chunk => {
  buf += chunk
  let i
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i)
    buf = buf.slice(i + 1)
    if (!line.trim()) continue
    let msg
    try { msg = JSON.parse(line) } catch { continue }
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id) }
  }
})

let id = 0
const call = (method, params) => new Promise(res => {
  const _id = ++id
  pending.set(_id, res)
  proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: _id, method, params }) + '\n')
})

await call('initialize', {
  protocolVersion: '2024-11-05',
  capabilities: {},
  clientInfo: { name: 'design-qa-verify', version: '0' },
})
proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n')

await call('tools/call', { name: 'browser_navigate', arguments: { url } })
await new Promise(r => setTimeout(r, 5000))

const res = await call('tools/call', {
  name: 'browser_evaluate',
  arguments: { function: '() => document.body.innerText.slice(0, 300)' },
})
const text = res.result?.content?.[0]?.text ?? ''

const shot = await call('tools/call', {
  name: 'browser_take_screenshot',
  arguments: { filename: basename(outPath), type: 'png' },
})
proc.kill()

if (shot.error || shot.result?.isError) {
  console.error('FAIL: 스크린샷 저장 실패 —', JSON.stringify(shot.error ?? shot.result?.content))
  process.exit(1)
}
if (!existsSync(outPath)) {
  console.error(`FAIL: ${outPath} 가 안 생겼다. MCP 응답:`, JSON.stringify(shot.result?.content))
  process.exit(1)
}

// 알려진 실패 모양 두 가지를 문장으로 가른다. VLM 이 보면 둘 다 "시안과 다름" 이다.
if (/Network Error/.test(text)) {
  console.error('FAIL: 앱이 Network Error 를 그렸다 — VPN 또는 local-network-access 문제다.')
  process.exit(1)
}
if (/로그인|login|sign in/i.test(text)) {
  console.error('FAIL: 로그인 화면이 찍혔다 — 세션이 안 먹었거나 만료됐다.')
  process.exit(1)
}
console.log('OK: 로그인 뒤 화면이 찍혔다.')
process.exit(0)
