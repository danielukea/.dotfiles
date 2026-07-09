---
name: html-mockup
description: >
  Build a static HTML mockup of a UI surface, grounded in the project's real design
  system — real components, tokens, CSS — rather than a generic invented look. Renders
  it locally in the browser for fast iteration. Use when you say "html mockup", "mock
  this up", "make a mockup", "show me what this would look like", "mock up this
  screen/page/feature", "prototype the UI in HTML", or when brainstorm's Prototype gear
  needs real visual fidelity rather than an ASCII wireframe. Not for structural/flow
  sketches (stay with Mermaid/ASCII in brainstorm for that) and not for planning the real
  implementation (a separate step, not this skill's job).
allowed-tools: Read, Grep, Glob, Write, Bash, Skill
---

# HTML Mockup

A disposable, static HTML mockup of one UI surface — fast to produce, grounded in what
the codebase actually looks like today, not a generic invented design language.

## Ground it first — the whole point of this skill
Before writing any markup, find the real design system for the surface you're mocking:
- **A system exists** (most cases): read 2-4 real files near the surface being mocked —
  actual component markup, a tokens/theme file, Tailwind config, or existing CSS. Extract
  the real vocabulary: color tokens, spacing scale, type scale, component class names and
  structure, border-radius/shadow conventions.
- **Nothing exists yet** (greenfield): say so explicitly — don't fake familiarity with a
  system that isn't there.

## Skill-load `artifact-design` for the fundamentals
`artifact-design` covers making an HTML page look deliberate rather than generic —
typography, color/type/layout, both-theme support, copy that isn't lorem. It defers to
an existing system when told about one, so hand it the real vocabulary you found — that's
what makes the output look like the product, not a generic AI page.

## Build with real content
Use the actual feature's real copy, data shape, and states — not lorem ipsum, not a
generic placeholder screen. A mockup of fake content is a mockup of something else.

## Render it locally
Write one self-contained `.html` file — inline all CSS/JS, no build step, no component
split. This is disposable scaffolding, not an app.
- **Already inside a brainstorm session with its live-preview server running?** Write the
  mockup into that server's content dir — it serves full `.html` documents as-is.
- **Otherwise**, write to the session scratchpad and open it directly: `open <file>.html`
  (macOS) or `xdg-open <file>.html` (Linux).

Iterate by overwriting the same file — feedback stays in the terminal.

## Premade templates
Mocking ActiveAdmin? Start from `templates/active-admin-{index,show,form}.html` (real AA 3.x
DOM/CSS) — see `references/active-admin.md` for what to prune per project.

## Gotchas
- **Not for a shareable link.** This is fast, disposable, local iteration. If the user
  wants something durable to hand off or share, use the Artifact tool directly — it loads
  `artifact-design` itself.
- **ActiveAdmin is light-theme only.** Don't add a dark-mode variant to the templates —
  that would be less faithful to the real system, not more.
