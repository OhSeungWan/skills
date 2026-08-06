# Writing Background and Intuition

이 문서는 code·spec 두 분기가 공유한다. 본문은 코드 변경(handoff)을 기준으로 서술하고, 제안 설계(spec 분기)에서 달라지는 것은 마지막 절 "spec 분기: 제안 설계를 다룰 때"에 모아 두었다 — spec 분기 실행 시 그 절을 반드시 함께 적용한다.

A reader opens a handoff document because they need to sign off on a change they didn't write, or maintain a change someone else's agent produced. What they're fighting is cognitive debt — the accumulation of decisions nobody actually understood at the time they were approved. The Background and Intuition sections are the first two chances to pay that debt down, and they fail in the same way almost every time: by leading with the code and hoping the point emerges by induction. It doesn't. State the point, then let the code confirm it.

This document explains how to write both sections so that never happens — how to give Background enough depth for a newcomer without boring the expert, how to make Intuition land with something concrete rather than abstract, how to keep the prose in a style that reads rather than lectures, and how to make the whole thing skippable for a reader who already knows half of it.

## Intuition first, detail after

Before you write a single line of code walkthrough, write the one-sentence version of what this change actually does and why it matters. Not a summary of the diff — a sentence a colleague could repeat back correctly after hearing it once. "This change replaces the retry loop's fixed one-second delay with an exponential backoff, because the fixed delay was causing a thundering herd every time the downstream service restarted." That sentence is the intuition. Everything else in Background, Intuition, and the branch-specific section exists to support, unpack, or justify it.

The failure mode this rule exists to prevent is the document that opens with "Let's look at `RetryPolicy.java`" and walks through the diff hunk by hunk, trusting the reader to assemble the point themselves by the time they reach the last file. Some readers will get there. Most will skim, half-understand, and approve anyway — which is exactly the behavior a handoff is supposed to interrupt. Put the one-sentence point in the first paragraph of Background, restate a fuller version of it at the top of Intuition, and only then start building up the supporting detail. A reader who stops after the first paragraph should still walk away with the correct mental model, even if a shallower one than the reader who finishes the whole document.

This ordering — point, then justification, then mechanism — is the same shape Martin Kleppmann uses in *Designing Data-Intensive Applications*: a chapter never opens by describing an algorithm's steps, it opens by naming the problem the algorithm solves and why the obvious solution doesn't work, and only then walks through the mechanism knowing the reader already has somewhere to hang each detail.

## Background: deep for newcomers, skippable for everyone else

Background exists to answer one question: what did the reader need to already know about this system in order for the change to make sense? For a change to a retry policy, that's what the retry policy was doing before, why it existed, and what called it. For a change to a caching layer, that's the eviction policy already in place and the access pattern that motivated it. Background is not a summary of the diff — it's the context the diff assumes.

Write it for the newcomer on the team: the person who has never opened this file, doesn't know why the retry policy has a maximum-attempts cap, and would otherwise have to go spelunking through git blame and old pull requests to reconstruct the reasoning that's about to be relevant. Give that person enough that the rest of the document doesn't send them elsewhere. That means naming the relevant surrounding code by what it does, not just its file path — "the `RetryPolicy` class governs how the request pipeline responds to a downstream 5xx, and up to now every retry has waited a hardcoded one second" is deep enough for a newcomer to follow the rest of the document; "see `RetryPolicy.java`" is not.

But depth for the newcomer must not become a tax on the reader who already knows this part of the system cold. Structure Background so it can be skipped without cost:

- **Open with a heading or a bolded lead sentence that names what the section covers**, so a reader who already knows the retry policy's history can see that at a glance and jump past it — "**How retries currently work:**" followed by the explanation, not an unlabeled wall of paragraphs the reader has to read partway into before realizing they already know it.
- **Keep each piece of background self-contained enough to skip independently.** If Background covers both the retry policy's history and the shape of the downstream service's failure modes, a reader who knows the retry policy but not the downstream service should be able to skip the first and read only the second, rather than the two being so entangled that skipping either means losing both.
- **Never bury a fact the later sections depend on inside a paragraph that looks skippable.** If the reader needs to know that retries are only attempted for idempotent requests, that can't live as an aside in the middle of three paragraphs of history — pull it out, bold it, or give it its own short paragraph, precisely because it's the kind of load-bearing detail an experienced reader might otherwise skim past thinking they already know this part.

The test for whether Background is calibrated correctly: could someone who joined the team yesterday follow the rest of the document without asking a single clarifying question about the surrounding system, and could someone who's owned this file for two years skip straight past it without missing anything the rest of the document needs?

## Intuition: make it concrete before it's abstract

Once Background has established the surrounding context, Intuition earns the reader's understanding of the change itself, and it does that with the same tool a good conversation does: a concrete example. Not a description of the mechanism in the abstract — an actual instance of it happening, with numbers or names a reader can hold in their head.

Take the exponential backoff example again. A poor Intuition section describes the algorithm: "the retry delay grows exponentially with each attempt, up to a maximum, with jitter added to avoid synchronized retries across clients." That's accurate and it's also nearly impossible to picture. A good Intuition section walks through toy data instead: "Say the downstream service goes down for four seconds. Under the old fixed delay, every one of the 200 clients currently waiting on a request retries at almost exactly the one-second mark, then again at two seconds, then three — all 200 requests landing on the service in the same few hundred milliseconds, right as it's trying to recover. Under the new policy, those same 200 clients retry after intervals drawn from 1s, 2s, 4s, 8s *plus* a random jitter of up to 500ms each — so instead of one spike of 200 simultaneous requests, the service sees a trickle of arrivals spread across several seconds." The second version gives the reader something to simulate in their head: a before-state, a specific number of clients, a concrete timeline, and an after-state they can compare against it.

Toy data works the same way for data structures and configuration as it does for timing. If the change alters how a cache key is constructed, don't say "the key now includes the tenant ID to prevent cross-tenant collisions" and stop — show one before-key and one after-key side by side (`cache:user:42` becoming `cache:tenant-7:user:42`), and say which two tenants would have collided under the old scheme. A reader who sees the actual string is convinced in a way a reader who's told about the string is not.

When the concept has a shape that's easier to see than to read — a timeline, a state machine, a before/after comparison — build a small diagram in HTML, CSS, and inline SVG rather than describing it purely in prose, and never in ASCII art. ASCII diagrams can't be restyled for the reader's light or dark theme, don't scale to different screen widths, and cap out at a fixed level of detail no matter how the concept grows; an SVG shape or a CSS layout can label precisely, align precisely, and be handed off as an interactive figure if the concept warrants one (see `references/interactive-figures.md` for when a diagram should go one step further and become something the reader can drag and manipulate directly, rather than just look at).

A useful check before finishing Intuition: if you deleted every sentence that describes the mechanism in the abstract and kept only the concrete example, would a reader who has never seen this code still come away with the right mental model? If yes, the section is doing its job — the abstract description is there to generalize the example, not to carry the weight on its own.

## Style: clear, flowing, classic prose

The prose in Background and Intuition — and really, everywhere in the document except the branch section's necessarily more clipped callouts — should read the way Martin Kleppmann writes: plain declarative sentences, one idea to a sentence, technical terms introduced with a short explanation the first time they appear rather than assumed, and transitions that make the logical connection between paragraphs explicit instead of leaving the reader to infer it. Kleppmann rarely uses a complicated sentence to say something a simple one could say just as well, and he never uses jargon to sound authoritative — every term he introduces, he explains, even ones a specialist reader would already know, because the cost of explaining a familiar term to an expert is one skimmed sentence, while the cost of not explaining an unfamiliar term to a newcomer is losing them for the rest of the paragraph.

Concretely, that means:

- Prefer short declarative sentences over long compound ones. If a sentence needs three commas and a semicolon to hold together, it's usually two sentences that haven't been separated yet.
- State causality explicitly. Not "the delay was fixed at one second, causing issues under load" — say what the issue actually was: "the delay was fixed at one second, which meant every client synchronized its retries and hit the recovering service in the same instant."
- Avoid hedge words and marketing language. "Significantly improves reliability" says nothing measurable; "reduces the retry storm from 200 simultaneous requests to a spread of arrivals over several seconds" says something the reader can verify.
- Introduce a term once, plainly, before using it freely. If Background is the first place "idempotent" appears, define it in one clause the first time ("retried safely because repeating it has no additional effect") rather than assuming the reader already carries the definition.

**Use callout blocks to carry the two kinds of content that shouldn't be left buried in a paragraph: the key concept the reader must not miss, and any edge case that would otherwise slip past as an aside.** A callout for "retries only happen for GET and other idempotent requests — a POST that fails is never automatically retried" pulls a load-bearing fact out where a skimming reader will actually see it. A callout for "if the maximum attempt count is reached, the request fails with the original error, not a timeout" flags an edge case the reader needs to know when they're debugging failures later. Reserve callouts for content that changes what the reader does or believes if they miss it — sprinkling them everywhere just makes them as easy to skim past as an ordinary paragraph.

## Personalization: structure for skipping, not just for reading start to finish

The same reader who skips the parts of Background they already know will also want to skip parts of Intuition — the reader who already understands why thundering herds happen doesn't need the toy example re-explaining it, only the specific numbers this change uses. Two structural habits make that possible:

- **Lead each subsection with what it covers, in bold or as a heading, before the explanation itself.** A reader scanning for "do I already know this" needs to answer that question from the lead sentence, not from reading three paragraphs.
- **Separate "what's generally true about this kind of problem" from "what specifically this change does about it."** A reader who already understands exponential backoff as a concept should be able to skip past the general explanation and land directly on the paragraph that says which base delay, which cap, and which jitter window this specific change uses — because that's the part they don't already know and can't get anywhere else.

This is also exactly what makes the table of contents at the top of the document (see `references/notion-assembly.md`) worth anything in practice: an accurate TOC only lets a reader "skip what you already know" if what they'd be skipping to is itself structured so the skip lands somewhere useful, rather than mid-explanation.

## spec 분기: 제안 설계를 다룰 때

spec 분기의 독자는 *아직 존재하지 않는* 설계를 승인하려는 참이다 — 코드도, 테스트도, 컴파일러도 아직 아무 가정을 검증하지 않았고, 검증자는 독자의 판단뿐이다. 위 규칙 전부가 그대로 적용되지만, 다음 네 가지가 추가로 달라진다:

1. **멘탈모델 문장의 형태가 고정된다**: **"이 설계는 X를 Y로 바꾼다, 왜냐하면 Z"**. diff 요약이 아니라 설계의 제안을 한 줄로 담는 형태다. 이 문장이 Background 첫 문단과 Intuition 상단에 온다.
2. **모든 구체 예시에 proposed(미구현) 표시를 유지한다.** Intuition의 toy-data 워크스루와 before/after 비교는 전부 *제안된 것*을 서술한다 — 괄호 표시, 콜아웃, 또는 "**제안된 흐름 (미구현):**" 같은 라벨로, 훑어 읽는 독자가 가상의 트레이스를 관측된 것으로 오인하지 않게 한다. before 쪽은 *오늘의* 시스템(관측된 사실), after 쪽은 *제안*(가설)이다 — 라벨이 그 경계를 지킨다.
3. **Background는 오늘의 시스템만 서술한다.** 제안이 만들어 낼 상태가 아니라, 제안이 전제하는 현재 상태를. "이 설계가 말이 되려면 독자가 오늘 시스템에 대해 무엇을 이미 알아야 하는가"가 기준이다.
4. **그림도 proposed를 표시한다.** before/after를 담은 다이어그램·인터랙티브 그림은 제안된 절반을 관측된 절반과 시각적으로 구분해 표시한다(`references/interactive-figures.md`).

Intuition 마무리 검사도 한 줄 늘어난다: 구체 예시만 남겨도 올바른 멘탈모델이 서는가 — **그리고 라벨만으로도 이것이 아직 만들어지지 않았음을 알 수 있는가?**

## A short checklist before moving on

- Does the very first paragraph of Background state the one-sentence point, in words a colleague could repeat back correctly?
- Could a newcomer follow the rest of the document from Background alone, without needing to look anything else up?
- Could an expert on this part of the system skip Background entirely and lose nothing the rest of the document depends on?
- Does Intuition contain at least one concrete example — real numbers, real strings, a real before/after — rather than only an abstract description of the mechanism?
- Is every diagram built in HTML/CSS/SVG, with no ASCII art anywhere?
- Does every load-bearing fact or edge case live in a callout or a clearly separated sentence, rather than buried mid-paragraph?
- (spec 분기) Is every hypothetical trace and after-state labeled as proposed, so concreteness never gets mistaken for existence?
