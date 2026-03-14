# mdeditor

> ⚠️ **Legacy-Modul** - Für neue Projekte wird `mdtext` empfohlen.

## Zweck

`mdeditor` ist ein einfaches Editor-Widget für Markdown-Text.

---

## Migration zu mdtext

```tcl
# ALT (mdeditor)
set ed [mdeditor::create .ed]
mdeditor::setContent $ed $text
set text [mdeditor::getContent $ed]

# NEU (mdtext)
set ed [mdtext::create .ed]
$ed set $text
set text [$ed get]
```

---

## Öffentliche API

```tcl
package require mdeditor 0.1

set ed [mdeditor::create $parent]
mdeditor::setContent $ed $text
set text [mdeditor::getContent $ed]
set modified [mdeditor::isModified $ed]
mdeditor::clearModified $ed
```
