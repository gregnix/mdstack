# mdtext

## Purpose

`mdtext` is a **Markdown editor widget** for Tcl/Tk.

The module:
- is a **pure editor widget** (no preview)
- provides **Smart Return** (list continuation)
- provides **Tab/Shift-Tab** (indentation)
- has **no application logic** (no save/open)

---

## Dependencies

- Tcl/Tk ≥ 8.6
- No other dependencies

---

## Public API

### `mdtext::create path ?options?`

Creates an editor widget.

```tcl
set editor [mdtext::create .editor]
pack $editor -fill both -expand 1
```

All Tk text widget options are passed through:

```tcl
set editor [mdtext::create .editor \
    -width 80 -height 30 \
    -font "Consolas 12" -wrap word]
```

Defaults: `-undo 1`, `-wrap word`, `-font TkFixedFont`

---

### Enable features

```tcl
$editor enableFeature smartReturn   ;# list continuation on Return
$editor enableFeature indent        ;# Tab/Shift-Tab indentation
```

Features are **disabled** by default.

---

### Basic API

| Command | Description |
|---------|-------------|
| `$editor get` | Get text |
| `$editor set $text` | Set text |
| `$editor clear` | Clear |
| `$editor modified` | Query modified status |
| `$editor modified 0` | Reset modified status |
| `$editor onchange $cb` | Set change callback |

---

### Formatting operations

| Command | Description |
|---------|-------------|
| `$editor wrap "**"` | Wrap selection with `**` (bold) |
| `$editor wrap "*"` | Wrap selection with `*` (italic) |
| `$editor wrap "\`"` | Wrap selection with backticks (code) |
| `$editor prefix "> "` | Prefix line (blockquote) |
| `$editor prefix "- "` | Prefix line (list) |
| `$editor heading 2` | Format line as H2 |
| `$editor codeblock tcl` | Insert code block |
| `$editor checkbox` | Toggle checkbox |
| `$editor table 3 4` | Insert 3×4 table |

---

### Context queries

| Command | Returns |
|---------|---------|
| `$editor lineType` | `heading` `list` `numlist` `checkbox` `quote` `codeblock` `code` `text` `empty` |
| `$editor currentLine` | Current line text |
| `$editor getHeadings` | List of `{level text index}` |

---

### Widget access

```tcl
$editor widget   ;# widget path (for bind)
$editor text     ;# internal text command
```

---

## Smart Return

When `smartReturn` is enabled:

| Line type | Return behavior |
|-----------|----------------|
| List `- Item` | inserts `\n- ` |
| Numbered `1. Item` | inserts `\n2. ` |
| Checkbox `- [ ] Task` | inserts `\n- [ ] ` |
| Quote `> Text` | inserts `\n> ` |
| Empty list `- ` | deletes the line |

---

## Tab/Shift-Tab

When `indent` is enabled:

| Key | Behavior |
|-----|----------|
| Tab | insert 2 spaces / indent line |
| Shift-Tab | remove 2 spaces |

---

## Example: editor with live preview

```tcl
package require mdtext   0.1
package require mdparser 0.2
package require mdmodel  0.1
package require mdviewer 0.3

set editor  [mdtext::create   .editor]
set preview [mdviewer::create .preview]

$editor enableFeature smartReturn
$editor enableFeature indent

$editor onchange {
    set ast [mdparser::parse [$editor get]]
    set doc [mdmodel::new $ast]
    mdviewer::renderModel .preview $doc
}
```

---

## Non-goals

- No preview (→ mdviewer)
- No parsing (→ mdparser)
- No save/open (→ application)
- No toolbar (→ application)
