# mdstack::editorkit

> ⚠️ **Legacy module** — use `mdstack` + `mdstack::text` + `mdstack::viewer` for new projects.

## Purpose

`mdstack::editorkit` is an **editor subsystem** for Markdown with live preview.

It combines `mdeditor`, `mdstack::parser`, `mdstack::model`, and `mdstack::viewer` into a
consistent edit/preview pipeline.

---

## Dependencies

- Tcl/Tk ≥ 8.6
- mdstack::parser 0.2
- mdstack::model 0.1
- mdstack::viewer 0.3
- mdeditor 0.1

---

## Public API

### `mdstack::editorkit::create path ?options?`

Creates an editor subsystem (split view).

```tcl
set kit [mdstack::editorkit::create .kit]
pack $kit -fill both -expand 1
```

| Option | Default | Description |
|--------|---------|-------------|
| `-debounce ms` | `300` | Delay between edit and re-parse |
| `-mode` | `split` | `edit`, `preview`, or `split` |
| `-onerror cmdPrefix` | — | Error callback |
| `-onchange cmdPrefix` | — | Change callback |
| `-onlink cmdPrefix` | — | Link click callback (passed to mdstack::viewer) |

---

### `mdstack::editorkit::settext path markdown`

Sets the Markdown text and triggers immediate parsing.

### `mdstack::editorkit::gettext path`

Returns the current Markdown text.

### `mdstack::editorkit::setmode path edit|preview|split`

Switches the display mode.

### `mdstack::editorkit::model path`

Returns the edit model v1 dict (text, dirty, cursor, selection).

### `mdstack::editorkit::setmodel path editModelDict`

Sets the editor state (for undo/restore).

### `mdstack::editorkit::getdocmodel path`

Returns the mdstack::model document model.

```tcl
set doc [mdstack::editorkit::getdocmodel $kit]
set toc [mdstack::model::toc $doc]
set hits [mdstack::model::find $doc "search term"]
```

---

## Error handling

- Parser errors are caught
- Preview stays on the last valid state
- Errors are reported via `-onerror`
- Editor always remains usable

---

## Non-goals

- No file management
- No search UI
- No publishing
