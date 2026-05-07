# mdstack::outline

## Purpose

`mdstack::outline` displays the **heading structure** of a Markdown document
as a clickable tree. Clicking a heading jumps to that position in the editor.

The module:
- reads headings from an `mdstack::text` editor widget
- displays them as a `ttk::treeview`
- auto-refreshes on changes (configurable interval)
- is a **pure UI widget** with no business logic

---

## Dependencies

- Tcl/Tk ≥ 8.6
- `mdstack::text 0.1` (as editor source)

---

## Public API

### `mdstack::outline::create path ?options?`

Creates an outline panel.

```tcl
set outline [mdstack::outline::create .outline -editor .editor]
pack $outline -fill both -expand 1
```

#### Options

| Option | Default | Description |
|--------|---------|-------------|
| `-editor` | — | **Required.** Path to the `mdstack::text` editor widget |
| `-refresh` | `500` | Refresh interval in milliseconds |

**Return value:** `path` (the created widget)

---

### `mdstack::outline::refresh path`

Re-reads the editor content and updates the tree immediately.

```tcl
mdstack::outline::refresh .outline
```

---

### `mdstack::outline::gotoSelection path`

Jumps to the currently selected heading in the editor.
Normally called automatically on `<<TreeviewSelect>>`.

```tcl
mdstack::outline::gotoSelection .outline
```

---

### `mdstack::outline::dispatch path subcmd ?args?`

Dispatch interface for external callers.

```tcl
mdstack::outline::dispatch .outline refresh
```

---

### `mdstack::outline::destroy path`

Releases resources and removes the widget.

```tcl
mdstack::outline::destroy .outline
```

---

## Display

Headings are styled by level:

| Level | Style |
|-------|-------|
| h1 | 11pt bold |
| h2 | 10pt bold |
| h3 | 10pt normal |
| h4 | 9pt italic |
| h5 | 9pt normal |
| h6 | 8pt normal |

---

## Example

```tcl
package require mdstack::text    0.1
package require mdstack::outline 0.1

ttk::panedwindow .pw -orient horizontal
pack .pw -fill both -expand 1

set editor  [mdstack::text::create   .editor]
set outline [mdstack::outline::create .outline -editor .editor -refresh 300]

.pw add .outline -weight 0
.pw add .editor  -weight 1
```

---

## Non-goals

- No rendering (structure display only)
- No search
- No access to mdstack::viewer (mdstack::text only)
