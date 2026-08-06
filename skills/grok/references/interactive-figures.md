# Writing interactive figures

An interactive figure earns its place in a handoff only if it does something prose and static diagrams cannot: let the reader *feel* how the change behaves, rather than just read about it. This document explains why that matters, what a figure is allowed to touch, how to pick its medium, what separates a good figure from a bad one, and how to check it before you hand it over.

## Purpose: one concept, felt rather than described

Seymour Papert's idea of a microworld is the right mental model here. A microworld is a small, self-contained environment built around a single idea, simplified until that idea is the only thing left to explore. You don't read about gears turning against each other — you turn one and watch the other respond, and the relationship between them becomes obvious in a way no paragraph could make obvious. Bret Victor's "dragging the rock" example works the same way: instead of describing how a shadow's length depends on the sun's angle, you drag a slider and watch the shadow stretch, and the dependency stops being an abstract claim and becomes something you've seen happen under your own hand.

That is the bar for a figure in this skill. Before building one, name the single concept from the code change that the figure exists to convey — a debounce delay reshaping a stream of events, a cache eviction policy dropping the wrong entry, a rate limiter smoothing a burst of requests, a retry backoff spacing out attempts. If you can't name that one concept in a sentence, you don't yet know what the figure should do, and you should go back to the change and find it before writing any markup.

Crucially, the figure is not shippable software. It is not a demo of the feature, not a UI mockup, not a test harness. It has no error handling to speak of, no edge cases to cover beyond the one being illustrated, no persistence, no real data. Its only job is to make one idea tangible for a few minutes to a reader who is trying to understand what changed and why. Once that job is done, the figure has served its purpose — it doesn't need to be maintained, extended, or reused.

## Self-containment rules

Every interactive figure must run as a single HTML file with nothing else attached to it:

- All CSS lives inline in a `<style>` block in the document `<head>`. No linked stylesheets.
- All JavaScript lives inline in a `<script>` block at the end of the document. No linked scripts, no imports, no bundlers.
- No external CDNs, no web fonts, no external images, no network requests of any kind. The file must open and work correctly from `file://`, offline, with no internet connection at all.
- The one narrow exception is the SVG namespace declaration, `xmlns="http://www.w3.org/2000/svg"` (and its friends like `xmlns:xlink`). These are XML namespace identifiers, not network fetches — the browser never contacts w3.org to render an SVG — so they are allowed even though they look like URLs.
- The file must be 200 KiB (204800 bytes) or smaller. This is small enough to embed as a Notion attachment and small enough that it never feels heavy to open.

If the concept the figure illustrates is itself about external references or URLs — a widget that demonstrates what a validator flags, for instance — resist the temptation to write a literal `https://...`, `ws(s)://...`, or protocol-relative `//host` string directly into the HTML source as example data. A literal string in one of those forms trips `scripts/check-self-contained.sh` (it can't tell your illustrative example from a real external reference); the validator does not match bare dotted names or filenames on their own (`example.com`, `foo.js` alone are fine), only `http(s)://`, `ws(s)://`, and protocol-relative `//host` references. Writing the example as one of those forms is undesirable anyway: it's not actually a network dependency, just a string that looks like one. Build any such example strings at runtime in JavaScript instead — concatenate the pieces, or assemble them from a data array — so the literal string never appears in the file's static source. The figure stays genuinely self-contained, and it passes its own check.

Start every new figure by copying `assets/figure-template.html` and editing it in place, rather than writing a figure from scratch. The template already has the self-contained skeleton wired correctly — the `<style>` block, the SVG stage, a single slider control, and the JavaScript that connects the slider to the visual. Editing a known-good skeleton is far less error-prone than reassembling the self-containment rules from memory each time.

## Choosing a medium

The template ships with inline SVG as its default stage, but SVG is not always the right choice. Pick the medium based on what the concept actually looks like:

- **Inline SVG** — use this when the concept is about coordinates, geometry, or a state machine with a small, fixed number of discrete states (a handful of shapes, a graph with a few nodes, a value moving along an axis). SVG elements are addressable by ID, so wiring a control to an attribute (`cx`, `transform`, `fill`, `d`) is direct and the DOM stays inspectable.
- **Canvas** — use this when you're drawing pixels directly, animating continuously, or rendering many particles or data points where creating one DOM/SVG node per item would be wasteful (a scatter of hundreds of points, a physics-like simulation, a heatmap). Canvas trades inspectability for raw drawing throughput.
- **Plain DOM** — use this when the concept is structural rather than spatial: a form whose fields depend on each other, a list that reorders or filters, a tree that expands and collapses. Here the browser's native layout and interaction model (labels, inputs, list items) is a better fit than drawing shapes.

If you're unsure, default to SVG — it covers the largest share of "one slider moves one thing" figures that this skill is built around, which is exactly why the template uses it.

## Principles of a good figure

- **The manipulated thing must be the concept, not a decoration.** If the change is about a timeout value, the control should adjust the timeout and the visual should show its consequence (a request finishing before or after a deadline line) — not an unrelated color picker or a totally separate toy.
- **Keep controls to one or two.** A single slider, or a slider plus a toggle, is enough to explore almost any concept worth illustrating in a handoff. Every extra control divides the reader's attention and multiplies the number of states they have to hold in their head. If you find yourself wanting a third control, that's usually a sign you're trying to illustrate two concepts at once — split them, or cut the figure down to the one that matters most.
- **Response must be immediate.** The visual and any numeric readout should update as the control moves — on the `input` event, not on release, and not after a delay. The whole point of dragging the rock is that the shadow moves *while* you drag; a figure that requires you to let go and wait breaks the feeling of manipulation the microworld is trying to create.
- **Data must be toy-sized.** A handful of points, a few items in a list, small numbers that are easy to read at a glance. The figure is not a benchmark or a stress test — realistic-looking data with hundreds of rows or long ID strings only adds noise that competes with the one idea the reader is meant to notice.

## Anti-patterns

- **Interaction as a crutch.** Adding a slider or button because "the skill wants something interactive" rather than because moving it reveals something true about the change. If a static picture would communicate the concept just as well, don't force in a control — the fake interactivity reads as busywork and erodes trust in the figures that actually matter.
- **Spectacle unrelated to the concept.** Gradients, particle effects, bouncy easing, or elaborate color schemes that have nothing to do with what changed. They make the figure feel more like a portfolio piece than an explanation, and they distract from the one thing the reader is supposed to notice.
- **Reaching for external libraries.** No D3, no charting libraries, no icon fonts, no CSS frameworks pulled from a CDN. Every dependency is another way the file stops being self-contained, another thing that can 404 later, and another few hundred KiB pushing against the 200 KiB ceiling. Plain SVG, canvas, and DOM APIs are enough for the small, single-concept figures this skill produces — if they don't feel like enough, the concept is probably too big for one figure.

## Verification

After writing or editing a figure, always run it through the validator before considering it done:

```bash
bash skills/grok/scripts/check-self-contained.sh path/to/figure.html
```

A pass looks like `OK: path/to/figure.html (N bytes, self-contained)` with exit code 0. A failure reports either an oversized file or the specific external references it found — `http(s)://`, `ws(s)://`, or protocol-relative `//host` references (the w3.org SVG namespace is excluded from that check, so it never causes a false failure). Never hand off a figure that hasn't passed this check — an external reference that works on your machine can silently fail to load for the reader, which defeats the figure's entire purpose, and a file over 200 KiB may not embed cleanly wherever the handoff is delivered.

Finally, remember that diagrams inside a figure — or anywhere else in a handoff — are drawn with HTML, CSS, and SVG, never ASCII art. ASCII diagrams don't scale, don't restyle for light or dark mode, and can't be made interactive; a `<div>` layout or an inline `<svg>` shape can do everything an ASCII box-and-arrow diagram does, and do it better.
