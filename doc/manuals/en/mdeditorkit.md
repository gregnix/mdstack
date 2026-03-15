# mdeditorkit

> ⚠️ **Legacy module** — use `mdstack` + `mdtext` + `mdviewer` for new projects.

## Purpose

`mdeditorkit` is an **editor subsystem** for Markdown with live preview.

It combines `mdeditor`, `mdparser`, `mdmodel`, and `mdviewer` into a
consistent edit/preview pipeline.

---

## Dependencies

- Tcl/Tk ≥ 8.6
- mdparser 0.2
- mdmodel 0.1
- mdviewer 0.3
- mdeditor 0.1

---

## Public API

### `mdeditorkit::create path ?options?`

Creates an editor subsystem (split view).

```tcl
set kit [mdeditorkit::create .kit]
pack $kit -fill both -expand 1
```

| Option | Default | Description |
|--------|---------|-------------|
| `-debounce ms` | `300` | Delay between edit and re-parse |
| `-mode` | `split` | `edit`, `preview`, or `split` |
| `-onerror cmdPrefix` | — | Error callback |
| `-onchange cmdPrefix` | — | Change callback |
| `-onlink cmdPrefix` | — | Link click callback (passed to mdviewer) |

---

### `mdeditorkit::settext path markdown`

Sets the Markdown text and triggers immediate parsing.

### `mdeditorkit::gettext path`

Returns the current Markdown text.

### `mdeditorkit::setmode path edit|preview|split`

Switches the display mode.

### `mdeditorkit::model path`

Returns the edit model v1 dict (text, dirty, cursor, selection).

### `mdeditorkit::setmodel path editModelDict`

Sets the editor state (for undo/restore).

### `mdeditorkit::getdocmodel path`

Returns the mdmodel document model.

```tcl
set doc [mdeditorkit::getdocmodel $kit]
set toc [mdmodel::toc $doc]
set hits [mdmodel::find $doc "search term"]
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
