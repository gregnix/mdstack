# mdcontextmenu

## Purpose

`mdcontextmenu` provides **right-click menus** for Markdown editors.

The module:
- is **editor-local** (no application logic)
- offers formatting actions
- offers insertion actions
- has **no save/open/preview** functions

---

## Dependencies

- Tcl/Tk ≥ 8.6
- `uicontextmenu 0.1`

---

## Public API

### `mdcontextmenu::attachToEditor editor`

Attaches the context menu to an mdtext editor.

```tcl
package require mdtext        0.1
package require uicontextmenu 0.1
package require mdcontextmenu 0.1

set editor [mdtext::create .editor]
mdcontextmenu::attachToEditor $editor
```

After this, **right-click** in the editor opens the menu.

---

## Menu entries

### Edit

| Entry | Accelerator | Description |
|-------|-------------|-------------|
| Cut | Ctrl+X | Selection to clipboard |
| Copy | Ctrl+C | Copy selection |
| Paste | Ctrl+V | Paste from clipboard |

### Formatting

| Entry | Accelerator | Description |
|-------|-------------|-------------|
| Bold | Ctrl+B | `**text**` |
| Italic | Ctrl+I | `*text*` |
| Code | Ctrl+\` | `` `text` `` |
| Strikethrough | — | `~~text~~` |

### Heading (submenu): H1–H6 (Ctrl+1 through Ctrl+3 for first three)

### List / Quote (submenu)

| Entry | Result |
|-------|--------|
| Unordered list | `- ` prefix |
| Ordered list | `1. ` prefix |
| Task list | `- [ ] ` prefix |
| Blockquote | `> ` prefix |

### Insert (submenu)

| Entry | Result |
|-------|--------|
| Link | `[label](url)` template |
| Image | `![alt](url)` template |
| Code block | ` ```\n\n``` ` |
| Table | 3×3 table template |
| Horizontal rule | `---` |

---

## Non-goals

- No file operations
- No preview
- No keyboard shortcut management (accelerators are display-only)
