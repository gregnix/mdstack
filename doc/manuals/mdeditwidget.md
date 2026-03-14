# mdeditwidget

> ⚠️ **Legacy-Modul** - Für neue Projekte wird `mdstack` + `mdtext` + `mdviewer` empfohlen.

## Zweck

`mdeditwidget` ist ein komplettes Editor-Widget mit Toolbar und File-Funktionen.

---

## Migration

Die Funktionalität von mdeditwidget wird jetzt durch separate Module bereitgestellt:

| Alt (mdeditwidget) | Neu |
|--------------------|-----|
| Toolbar | → Anwendung |
| Editor | → `mdtext` |
| Preview | → `mdviewer` |
| Orchestrierung | → `mdstack` |
| File Open/Save | → Anwendung |

---

## Öffentliche API

```tcl
package require mdeditwidget 0.1

set w [mdeditwidget::create .mde]
mdeditwidget::loadFile $w "README.md"
mdeditwidget::saveFile $w
```
