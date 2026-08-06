# Assembling the hybrid page in Notion

이 문서는 code·spec 두 분기가 공유하는 Notion 조립의 단일 출처다. quiz 분기는 Notion을 쓰지 않는다(산출물은 자기완결 HTML).

Everything a run produces — the background, the intuition, the branch-specific section (code walkthrough, or the surfaced 핵심 결정·가정·리스크 and 열린 질문), the quiz, and the interactive figure (when one exists) — can end up as a single Notion page that a teammate can read, comment on, and click around in. Getting the words right is only half the job; if the page is assembled wrong, the figure renders as a dead file attachment, the quiz reads as five paragraphs with no toggles, a stated decision and an unstated assumption look identical, or the whole thing lands in the wrong corner of the workspace where nobody will ever find it. This document is the exact, verified mechanism for getting the assembly right, plus the configuration logic for deciding where the page goes. Every call shape and every piece of embed syntax here was proven to work in a live spike against Notion; this file tells you how to reproduce it.

## Delivery role per branch

- **code 분기**: the Notion page **is the deliverable** — the durable archive of the handoff. That is why the self-check gate is hard for this branch: the upload sends the document to an external permanent store, so it doesn't leave until the check passes.
- **spec 분기**: the primary delivery is **터미널 인라인, at the approval gate itself** — the mental model, the 핵심 결정·가정·리스크 (with their `[명시]`/`[암묵]` labels, per `references/surfacing-decisions.md`), and the 열린 질문 render as plain text directly in the conversation where the human is about to approve or reject the design. That terminal rendering is not a preview of the Notion page — it is the deliverable. The Notion page is an **optional durable follow-up**, built only if the user says yes. A run that never touches Notion has still done its job.

Two pieces of content specifically *need* Notion's rendering and don't fully work as plain terminal text: the quiz's "think-then-reveal" nested toggles (a terminal can't withhold the answer behind a click), and the interactive figure (only Notion's `<embed>` rendering lets the reader drag the control).

## 사전 확인과 오류 처리

- **사전 확인** (code 분기): 문서 저작을 시작하기 전에 가벼운 호출(`notion-search`나 `notion-fetch`)로 연결 가능 여부를 확인한다. 안 되면 맨 앞에서 바로 사용자에게 알린다.
- **parent 오류 폴백**: `notion-create-pages`가 parent 오류(저장된 `notion_parent`가 삭제됐거나 무효)로 실패하면, `parent`를 생략하는 사설 페이지 경로로 폴백해 생성한다. 이후 폴백 사실을 경고로 알리고 `.claude/grok.json`의 `notion_parent` 재설정 방법을 설명한다.
- **첨부 만료**: `notion-create-attachment`로 올린 그림은 생성 후 약 1시간이 지나면 만료된다. 자기점검·재시도로 페이지 생성이 그 이상 지연됐다면, 만료된 첨부를 임베드하지 말고 그림을 다시 업로드한 뒤 그 결과로 임베드한다.

## Read the markdown spec first, every time

Before writing a single block of content, read the `notion://docs/enhanced-markdown-spec` MCP resource. Do this at the start of assembly, not from memory of a previous run. Notion's flavor of Markdown has its own rules for headings, code blocks, callouts, to-do blocks, and — critically — toggle blocks, and guessing at the syntax is how a quiz ends up as plain text instead of five clickable toggles, or a checklist ends up as a bulleted list nobody can check off. The resource is authoritative; treat any assumption about Notion Markdown syntax that isn't confirmed there as wrong until proven otherwise.

## Uploading the interactive figure (when one exists)

A spec-branch run may have no figure at all — per `references/interactive-figures.md`, a figure only earns its place when the design has a shape that's easier to feel than to read. If this run has no figure, skip this entire section.

When a figure *does* exist, it's the one piece of the page that isn't native Notion content — it's a self-contained HTML file (built per `references/interactive-figures.md` and checked with `scripts/check-self-contained.sh`) that has to be attached and then embedded. The round-trip is two calls, in this order.

**Step 1 — upload the HTML as an attachment.** Call `mcp__claude_ai_Notion__notion-create-attachment` with the figure's filename and its full HTML content inline:

```json
{
  "filename": "<slug>-figure.html",
  "content": "<!doctype html><html>...self-contained HTML, ≤200 KiB...</html>"
}
```

`<slug>` should identify the concept the figure illustrates (e.g. `backoff-figure.html`, `cache-key-figure.html`), not a generic name — if a run ever has more than one figure, generic names collide. The `content` field carries the entire HTML document as a string, inline, in the same call — there is no separate file upload step and no need to write the figure to disk first.

The response carries the fields that matter for the next step:

```json
{
  "file_upload_id": "3a148a03-3208-8118-8e8a-00b22c6766d5",
  "content_length": 252,
  "status": "uploaded",
  "markdown_source": "file-upload://3a148a03-3208-8118-8e8a-00b22c6766d5",
  "suggested_markdown": "<embed src=\"file-upload://3a148a03-3208-8118-8e8a-00b22c6766d5\"></embed>"
}
```

Hold onto `markdown_source` (or just the whole `suggested_markdown` string — the response hands you the exact embed tag ready to use). Confirm `status` is `"uploaded"` before moving on. Unattached uploads are temporary and expire roughly an hour after creation, so move straight on to Step 2 in the same run.

**Step 2 — place the embed in the page.** When you call `mcp__claude_ai_Notion__notion-create-pages` to build the page (see below), put the embed tag directly in the page `content` at the point in the Intuition section where the figure belongs:

```
<embed src="file-upload://3a148a03-3208-8118-8e8a-00b22c6766d5"></embed>
```

This is the one rule in this entire document that has zero tolerance for improvisation: **the figure must be placed as `<embed src="file-upload://...">`, never as a code block, never as a file block, never as a link.** A code block would show the reader raw HTML text instead of rendering it; a file block would offer the HTML as a download instead of an inline widget. Only the literal `<embed>` tag makes Notion render the attachment as a sandboxed, interactive preview in the page — this was verified directly: the spike's embedded widget responded to clicks and updated its counter live, exactly as it would in a browser.

## Assembling the hybrid page

The page is hybrid on purpose: prose is native Notion Markdown blocks, and only the interactive figure (when one exists) is an HTML embed. This split exists because native blocks support Notion's paragraph-level commenting — a teammate can highlight a specific sentence in Background, or a specific 결정 callout, and leave a question on it — while an embed cannot host that kind of granular comment. Putting the figure in as an embed is a deliberate, narrow exception, not a precedent for pushing more content into HTML. If you ever find yourself tempted to render a diagram, a table, or a passage of prose as HTML instead of Notion Markdown, don't — write it as native blocks instead so it stays commentable.

Build the whole page with one call to `mcp__claude_ai_Notion__notion-create-pages`, passing the resolved `parent` object (see below) at the top level of the call and, inside `pages: [{ content, properties }]`, a `content` string containing Notion-flavored Markdown for the branch's sections plus the embed at its place in Intuition, if a figure exists. `parent` and `content` are not siblings in the same object — `parent` sits alongside `pages` at the top of the call, while `content` sits inside each entry of the `pages` array. Concretely:

- **Background** and **Intuition** prose: ordinary Markdown paragraphs and headings — Notion converts these to native paragraph and heading blocks automatically.
- **Intuition**'s figure, when this run has one: the `<embed src="file-upload://...">` tag from the previous step, placed after the paragraph(s) that introduce the concept it illustrates.
- **Code** (code 분기): each code excerpt goes in a fenced code block (confirm the exact fence/language-tag syntax against the enhanced-markdown-spec resource), immediately followed by a callout block carrying the walkthrough prose for that excerpt — this pairing (code block, then callout explaining it) is what makes the Code section read as a literate walkthrough rather than a dump of files. Never render code as an image or as part of the figure HTML; code belongs in the page as text so it stays copyable and commentable.
- **핵심 결정·가정·리스크** (spec 분기): each load-bearing decision (identified per `references/surfacing-decisions.md`) becomes one or more **callout blocks**, never a fenced code block and never a plain paragraph — a decision buried in ordinary prose is exactly how a reader skims past something they should have argued with. Render each decision's four fields (①무엇을 정했나, ②왜 — 버려진 대안 포함, ③전제하는 가정, ④틀렸을 때의 비용/리스크) across callouts that apply the **stated-vs-implicit visual distinction** from `references/surfacing-decisions.md`:
  - Put ① and ② — content the skill can point at a line in the spec — into a callout using one color/icon (e.g. a neutral or blue callout, 📌), prefixed with the `[명시]` label and its citation, matching the terminal rendering's labeling convention.
  - Put ③ together with ④ into a **separate** callout, colored by whether ③ is stated or implicit: `[명시]` assumptions get the same color as the decision callout (with citation); `[암묵]` assumptions — inferred rather than read — get a visually distinct second color/icon (e.g. amber/yellow, 💭). The color pairing lets a reader tell "the spec's author committed to this" from "the skill inferred this" at a glance.
  - Confirm the exact callout Markdown (color/icon parameters included) against the enhanced-markdown-spec resource — a malformed callout degrades to a plain paragraph and silently erases the stated/implicit distinction.
- **열린 질문·확인 필요** (spec 분기): each open question becomes one **to-do (checklist) block**, not a bulleted list and not a callout — a reader can check an item off once it's decided, giving the archive a visible trail of which open questions got resolved. Each to-do's text follows the actionable form required by `references/surfacing-decisions.md`: the decision that needs making, its options, and where the spec left it open. Confirm the to-do block's syntax (e.g. `- [ ] `) against the spec resource; don't assume a plain `-` bullet with bracket text renders as a checkable block.
- **Quiz**: five *nested* toggle blocks, detailed next.

## The quiz as nested toggle blocks

The quiz is five questions, and each one is a **two-level nested toggle**, not a single flat one. The outer toggle's header is the question. Expanding it reveals the multiple-choice options (A/B/C/D) as visible text and then a second, nested toggle labelled "정답 확인" (or "정답 및 해설"); only expanding that inner toggle reveals the correct option plus a sentence or two on why. The reason for the nesting is specific and important: if the options and the answer share one toggle, expanding it shows both at once, so the reader sees the answer the instant they read the choices and never actually has to pick. Nesting restores the "read the options, think, then check" moment — which is the entire reason the quiz exists (see `references/writing-quizzes.md`). There is no hard gate on the reader — nothing blocks them from skipping the quiz or clicking straight through; the toggles are an opportunity to self-check, not an enforcement mechanism.

**This document is the single source of the nested-toggle mechanism** — `SKILL.md` and `references/writing-quizzes.md` point here rather than each carrying their own copy of the syntax, so if this rule ever needs to change, it changes in exactly one place.

The exact syntax was verified working directly against Notion. Use it as written, not an approximation of it:

```
<details>
<summary>다음 중 Notion에서 중첩 토글의 자식 블록을 만들 때 필요한 것은?</summary>
	A. 코드 블록으로 감싸기
	B. 파일 블록으로 감싸기
	C. 탭으로 들여쓰기
	D. 이미지 블록으로 감싸기
	<details>
	<summary>정답 확인</summary>
		정답: C
		근거: ...
	</details>
</details>
```

The rule that matters is indentation depth, not just tag nesting: the outer toggle's children (A/B/C/D and the inner toggle itself) are indented one tab; the inner "정답 확인" toggle's children (the answer and its rationale) are indented two tabs. `<details>`/`<summary>` tag-pairing is somewhat forgiving of a missing tab on its own, but don't rely on that leniency — always write both indentation levels explicitly, since it's the form Notion is guaranteed to render correctly and the form this document treats as canonical.

After creating the page, **re-fetch it and verify** that the inner "정답 확인" toggle is structurally **nested** inside the question toggle — its `<details>` opens and closes before the outer toggle's closing `</details>`, at one deeper level of tab indentation. This is the real failure mode to check for: a toggle whose child line is missing its tab indent silently degrades to a flat paragraph sitting *after* the toggle, with no error. Note what re-fetching can and cannot tell you: Notion's `notion-fetch` text always dumps a toggle's full content regardless of collapsed/expanded state, so **collapse-on-load is not something a fetch can observe** — it's simply the `<details>` default and doesn't need separate verification. What the fetch text *does* reliably show is containment: if the inner toggle's closing tag appears before the outer's, at the deeper indentation, the nesting is correct; if the inner toggle's content appears as sibling text after the outer toggle closes, the nesting was flattened and must be fixed before the page is considered done.

## Watch for Notion's automatic link conversion

Notion automatically turns bare domain-looking or filename-looking text (e.g. `foo.js`, `example.com`) into a clickable link, with no prompt and no way to opt out after the fact — this happens in the page title just as readily as in ordinary prose. A sentence that mentions a filename or a dotted identifier can silently grow an unwanted link. If an auto-link would appear somewhere it shouldn't, rephrase the text or wrap it as inline code (`` `foo.js` ``) instead — inline-code formatting reliably prevents the conversion.

## Table of contents

The page must open with a table of contents covering the branch's sections in order — code: Background, Intuition, Code, Quiz / spec: Background, Intuition, 핵심 결정·가정·리스크, 열린 질문·확인 필요, Quiz — before any of the section content begins. In Notion this is ordinarily a native table-of-contents block that auto-links to the headings beneath it; confirm its Markdown representation in the spec resource, since a wrong construct here just as easily degrades to flat text as it does for toggles and callouts. The point of the TOC is to let a reader who already knows the background jump straight to the meat — an accurate TOC is what makes the "skip what you already know" principle from `references/intuition-first.md` actually usable in practice.

## Resolving the Notion parent

Every page needs a parent — a Notion database or page it gets created under — and where that parent comes from is user-configurable. Resolve it in this exact order, stopping at the first source that yields a value:

1. **`--parent <id>` argument.** If the skill was invoked with an explicit `--parent`, use that id and skip every other step below.
2. **`.claude/grok.json` in the repo.** Read the `notion_parent` field:
   ```json
   {
     "notion_parent": {
       "type": "data_source_id",
       "id": "<uuid>"
     }
   }
   ```
   `type` is either `data_source_id` (the parent is a Notion database — the recommended form, see below) or `page_id` (a plain page). This config schema (`type` + `id`) is this skill's own shorthand, not the literal shape the Notion tool expects — when building the actual `notion-create-pages` call, translate it into that tool's `parent` object, which nests the id under a field named after the type itself: `{"type": "data_source_id", "data_source_id": "<uuid>"}` or `{"type": "page_id", "page_id": "<uuid>"}`. code와 spec 분기가 같은 파일을 공유한다 — 둘 다 아래의 통합 아카이브에 쌓이기 때문이다.
3. **Ask the user.** If neither of the above resolved, this is a first run for this repo — ask the user where pages should go, in plain terms ("a Notion database to collect these in, or a specific page?"). Once they answer, offer to save the choice into `.claude/grok.json` so future runs skip this question. Only write the file if the user agrees.
4. **Workspace private page fallback.** If the user has no preference right now (or can't be asked), fall back to omitting `parent` entirely in the `notion-create-pages` call — verified in the spike: omitting `parent` creates a workspace-level private page rather than erroring. Always tell the user afterward that the page landed as a private workspace page, and describe how to set `notion_parent` so future runs land somewhere permanent and discoverable.

### 데이터베이스 URL/ID 해석 (중요)

`--parent` 인자, `.claude/grok.json`, 혹은 사용자의 답변이 Notion **데이터베이스**의 URL이거나(예: `https://notion.so/.../<database-id>?v=...`) 데이터소스가 여러 개인 데이터베이스의 ID일 수 있다. `notion-create-pages`는 데이터소스가 둘 이상인 데이터베이스에 `database_id`를 그대로 쓸 수 없다. 그런 값을 받으면 페이지를 만들기 전에 반드시:

1. 먼저 `mcp__claude_ai_Notion__notion-fetch`를 그 데이터베이스 URL/ID로 호출해 스키마와 데이터소스 목록을 확인한다. 데이터소스 ID는 `<data-source url="collection://<data_source_id>">` 형태로 나타난다.
2. 상황에 맞는 `data_source_id` 하나를 선택하고, 그것을 `parent: {"type": "data_source_id", "data_source_id": "<data_source_id>"}`로 사용한다. 원본 데이터베이스 URL이나 `database_id`를 그대로 parent로 넘기지 않는다.
3. `.claude/grok.json`에 저장할 때도 이 **해석된 `data_source_id`(또는 `page_id`)**를 저장한다 — 원본 URL이나 database_id가 아니라. 저장된 값은 다음 실행에서 다시 fetch 없이 바로 `parent`에 쓸 수 있어야 한다.

이 세 단계를 거친 `data_source_id` 또는 `page_id`가 이 스킬이 다루는 유일한 parent 형태다. 일반 페이지(비-데이터베이스)의 URL/ID는 그대로 `page_id`로 쓴다.

## The recommended archive form: a unified Notion database

A page-per-page fallback works, but it scatters pages with no way to filter or search across them later. The recommended setup is to point `notion_parent` at a Notion **database** (`type: "data_source_id"`) dedicated to these pages — for example one named "Grok Archive." That database is **shared across branches**: a spec approved today and the code change landing weeks later both become rows in the same archive, which is what makes the provenance link below meaningful.

When the parent is a database, each new page becomes a **row** — but before writing that row, **reconcile against the target database's real schema**. Call `notion-fetch` on the data source and read back its actual property schema — never assume the logical fields below exist under these literal names or types. Map each logical field onto whatever property actually matches it *by intent*: a "Repo" property might really be named "Repository" or "Project," a "Date" property might be a date-type field called "Created." If a logical field has no plausibly corresponding property, don't silently write nothing and don't invent a property name that will be dropped — either create the missing property on the data source or explicitly warn the user. This schema fetch is **required on every run**, including runs against a database this skill has already written to: the stored `notion_parent` config only lets parent *resolution* be skipped, never schema reconciliation, because the schema can change between runs.

Once reconciled, the row carries at least these logical fields:

- **Date** — the date the page was generated.
- **Repo** — the repository name.
- **Branch** — the branch or commit range.
- **Summary** — a one-line description, written like a commit subject line: specific enough to distinguish this row at a glance.
- **Type** — `code` for code-branch rows, `spec` for spec-branch rows. If the reconciled property is a select/status field, the value must exist as an option (create it if not); if plain text, write the literal string. Never leave it blank — an unset Type defeats the field's whole purpose of telling the two apart at a glance.
- **spec→구현 relation** — a relation (or link/URL field) pointing from a spec row to the code row that later implements it. A spec-branch run writes this **empty** (the implementation doesn't exist yet). A code-branch run that implements a previously archived spec should populate the link back to that spec row. Reconcile by intent like the other fields; if no property exists, create it or warn — an approved spec with no way to trace which code fulfilled it is exactly the provenance gap this field closes.

This is what turns a pile of one-off pages into a searchable, filterable, *traceable* archive — and it only exists if Type and the provenance relation are actually populated (or deliberately left empty and explained) on every run, not treated as optional metadata.

## When a figure won't fit under 200 KiB

The inline attachment path used by `notion-create-attachment` has a firm ceiling of 200 KiB (204800 bytes) — the same limit `scripts/check-self-contained.sh` enforces before a figure ever reaches this stage. If a figure fails that check for size rather than for an external reference, don't attempt to upload it anyway; shrink it first: trim inline comments and whitespace, drop decorative CSS, reduce toy data to the smallest set that still makes the point, or — if the figure has genuinely grown to cover more than one concept — split it into two smaller figures, each earning its place under `references/interactive-figures.md`'s "one concept per figure" rule.

If none of that gets a figure under the limit, don't silently drop it and don't silently truncate it. Warn the user explicitly that the figure exceeds the 200 KiB inline limit and could not be embedded, and say so in the page itself (a short note in place of the missing embed) rather than leaving a silent gap.
