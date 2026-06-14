# mdstack 0.5.0 — loose lists / multi-block list items (design)

## Problem

`parseListLines` merges every continuation line of a list item into a **single
paragraph** (`append currentText " " <line>`). A blank line inside an item is
not even reached: `parseListBlock` *breaks* the list when a blank line is
followed by a non-marker line. Result: CommonMark loose lists and items with
several blocks render wrong.

- `- one`⏎⏎`  two`  → should be one item with two paragraphs; today the list
  ends after `one` and `two` becomes a separate top-level paragraph.
- ordered item with indented code / block quote → the nested block is dumped as
  a top-level sibling instead of belonging to the item.

## What does NOT change

- **AST shape:** `list_item` already carries `blocks [...]` (a list). The viewer
  already loops over all item blocks (`foreach subBlock [dict get $item blocks]`).
  So multi-block items need no schema change in mdstack.
- **Tight lists / lazy continuation:** lines without a blank between them stay a
  single paragraph (CommonMark lazy continuation). The existing
  `parser-multiline-list` / `parser-nested-lists` behaviour is preserved.

## Target behaviour

1. **`parseListBlock`** — keep the list open across a blank line when the *next*
   line is an indented continuation (`^\s{2,}\S`), not only when it is a marker.
   The blank line is collected into `listLines` so the item builder can see it.
2. **`parseListLines`** — within one item, a blank line separates blocks: flush
   the current paragraph and start a new one. An item's `blocks` becomes
   `[paragraph … , paragraph … , <sublist?> …]`.
3. **loose flag** — a list is *loose* if any blank line separates items or blocks
   within an item. Record `loose 1|0` on the list dict so renderers can decide
   `<p>`-wrapping. (Tight = inline item text, loose = each block wrapped.)

### Staging

- **Step 1 (this change):** multi-*paragraph* items + `loose` flag. Covers the
  common case (`- one`⏎⏎`  two`). Surgical change to the two procs above; the
  AST stays `blocks [paragraph …]`.
- **Step 2 (later):** full nested blocks in items (indented code, block quotes,
  nested fenced code) by de-indenting an item's lines and running `parseBlocks`
  recursively. Higher risk; deferred so Step 1 can ship and be measured.

## Consumer impact

- **mdstack viewer** — already iterates all item blocks; needs only loose/tight
  `<p>`-spacing polish (Step 1 keeps current spacing; revisit if needed).
- **docir `md::_mapList`** — today takes *first paragraph* inlines as the item
  content and flattens the rest as trailing siblings (its own comment notes the
  DocIR schema allows only `listItem` nodes in `list.content`). For loose items
  it must render *all* paragraph blocks of an item. This is the **docir-side
  work** that pairs with Step 1; DocIR's list schema (one inline run per item)
  is the real long-term constraint and is tracked separately.
- **docir renderers (html/odt/pdf/roff/tk)** — inherit whatever `_mapList`
  produces; no direct change for Step 1.

Because every docir Markdown conversion runs `mdstack::parser::parse →
docir::md::fromAst`, the parser change reaches md2html/md2odt/md2pdf/md2man and
mdstack::html/pdf once `_mapList` is updated.

## Versioning (→ 0.5.0)

- `mdstack::parser` 0.2 → **0.5.0** (file rename `parser-0.2.tm` → `parser-0.5.0.tm`).
  Consumers use minimum-version requires (`package require mdstack::parser 0.2`),
  which Tcl satisfies with 0.5.0 — no consumer edits required, but verify.
- Record the milestone in `CHANGELOG.md` as `0.5.0` (loose lists + the emphasis
  flanking already landed).
- The rename + bump happen **after** the feature is implemented and the full
  suite is green, to avoid a half-renamed tree.

## Test plan

- New `parser-loose-lists.tcl`: `- one`⏎⏎`  two` → item 0 has ≥2 paragraph
  blocks; tight list `- a`⏎`- b` → items have exactly one paragraph; `loose`
  flag set correctly; ordered loose lists.
- Regression: `parser-multiline-list`, `parser-nested-lists`, all core/inline.
- Conformance delta on “List items” / “Lists”.

## Step 1 — status (implemented)

- **Parser:** done. `parseListBlock` keeps the list open across blank + 2-3-space
  continuation (4-space/tab stays indented code → list ends, preserving the
  existing `indent-list-1` / `ml-blank-stops` behaviour). `parseListLines`
  rewritten to emit multiple paragraph blocks per item via `_mkListItem`; list
  gains a `loose` flag. All parser/core/inline tests green; new
  `parser-loose-lists.tcl` (6/6).
- **Tk viewer:** renders loose items already (loops `item blocks`) — verified.
- **Version:** `mdstack::parser` → 0.5.0 (file + `lib/pkgIndex.tcl` bumped).
- **Conformance:** unchanged via the docir runner — expected, because the
  conformance HTML is produced by docir, whose `_mapList` still flattens. The
  parser AST is now correct; the gain appears once the docir side lands.

## Step 1b — pending (docir side, separate)

`docir::md::_mapList` must map *all* paragraph blocks of an item, and DocIR's
list schema (currently one inline run per `listItem`) must allow block content.
That is the cross-repo IR change; doing it unlocks loose lists in
md2html/md2odt/md2pdf/md2man and mdstack::html/pdf.

## Step 1b — status (implemented, docir side)

Done via an **additive, backward-compatible** DocIR extension (no flat-IR break):
- `docir::md::_mapList`: a `listItem` now carries `content` = *all* the item's
  paragraphs (space-joined) so any renderer shows the full text; multi-paragraph
  items additionally carry `blocks` (the paragraph nodes); the `list` node's meta
  carries `loose 0|1`. Sub-lists stay trailing siblings (unchanged).
- `docir::html`: renders `blocks` as one `<p>` per paragraph inside the `<li>`;
  loose single-paragraph items wrap `content` in `<p>`; tight items stay inline
  (`<li>text</li>`) exactly as before.
- pdf / roff / odt: **unchanged code** — they read `content`, which now holds the
  full text, so no data is lost. Verified: roff shows all paragraphs; docir
  html/md/roff/pdf/canvas/list-indent/bridge/tilemd/tilehtml tests all green;
  `test-docir-odt` not runnable in sandbox (missing `odf::text`) but odt code is
  untouched.

Result: loose lists render correctly in the Tk viewer, mdstack::html, md2html and
md2tilehtml. Conformance: strict 27.8→28.2 %, lenient 33.7→34.2 %; List items
14.6→16.7 %, Lists 11.5→19.2 %.

### Per-paragraph breaks in other formats — status
- **roff:** done — `_renderListItem` reads `blocks`, paragraphs separated by `.sp`.
  Verified in sandbox.
- **pdf:** done and **verified** — `_renderListItemMarker` renders further
  paragraphs hang-indented to the text column. Real render with pdf4tcl 0.9.4.25
  + pdf4tcllib produced a valid PDF; extracted text confirms continuation
  paragraphs ("two" under "one", "beta" under "alpha") on their own indented lines.
- **odt:** unchanged — still renders `content` (all text, space-joined). Proper
  per-paragraph breaks need the ODT multi-`text:p`-per-item API; deferred. No data
  loss without it.
