# Tcl/Tk Manuals mit mdserver anzeigen

**Stand:** 2026-03-15  
**Betrifft:** nroff2md v0.1, mdserver v0.4  
**Voraussetzung:** Tcl/Tk 9.0.3 Quelldistribution oder installierte Manpages

Die Tcl/Tk-Dokumentation liegt in der Quelldistribution als nroff-Manpages vor
(`.n` und `.3`). Mit `nroff2md` werden sie einmalig nach Markdown konvertiert und
dann über `mdserver` als navigierbare Web-Seite ausgeliefert.

---

## Überblick: Datenpipeline

```
Quelldistribution
  tcltkdoc/tcl9.0/doc/*.n    nroff-Quellformat (Tcl)
  tcltkdoc/tk9.0/doc/*.n     nroff-Quellformat (Tk)
        |
        v nroff2md.tcl --batch --linkmode server
  sites/tcltk/md/*.md        Markdown (425 Seiten + index.md)
        |
        v mdserver.tcl
  http://localhost:8080/     Browser
```

---

## Schritt 1: Verzeichnisstruktur anlegen

```bash
mkdir -p sites/tcltk/md
```

Die Site-Struktur des mdserver-Projekts:

```
site/
  tools/
    nroff2md.tcl        Konverter (standalone, alle Module eingebettet)
  sites/
    tcltk/
      md/               Konvertierte Manpages (wird erzeugt)
  mdserver.tcl          Server
```

---

## Schritt 2: Manpages konvertieren

### Tcl und Tk in einem Schritt

`nroff2md --batch` sucht rekursiv nach `.n`- und `.3`-Dateien:

```bash
tclsh tools/nroff2md.tcl \
  --batch tcltkdoc/ \
  sites/tcltk/md/ \
  --linkmode server
```

Ausgabe (Auszug):

```
Written: sites/tcltk/md/dict.md
Written: sites/tcltk/md/chan.md
...
Converted: 425  Failed: 0  Total: 425
Index:   sites/tcltk/md/index.md (425 entries)
```

Ein einziger Aufruf genügt — `tcl9.0/doc/` und `tk9.0/doc/` werden
automatisch gefunden.

### Was wird erzeugt

**`sites/tcltk/md/*.md`** — 425 konvertierte Manpages, jede beginnt mit:
```markdown
[<< Index](index.md)
```

**`sites/tcltk/md/index.md`** — kategorisiertes Inhaltsverzeichnis:

```markdown
## Tcl Commands

[A](#tcl-a) | [B](#tcl-b) | [C](#tcl-c) | ...

### tcl-a

- [after(n)](/after)
- [apply(n)](/apply)
- [array(n)](/array)

## Tk Commands

[B](#tk-b) | [C](#tk-c) | ...

## C API

[A](#c-a) | ...
```

### Link-Modi

| Modus | Verwendung | Links |
|-------|-----------|-------|
| `--linkmode server` | mit mdserver | `/pagename` |
| `--linkmode file` | Dateisystem/Editor | `pagename.md` |
| `--linkmode none` | kein Linking (Standard) | Plaintext |

### Ohne Index

```bash
tclsh tools/nroff2md.tcl --batch tcltkdoc/ sites/tcltk/md/ --no-index
```

---

## Schritt 3: mdserver starten

```bash
tclsh mdserver.tcl \
  --root sites/tcltk/md/ \
  --port 8080
```

Ausgabe:

```
mdserver 0.4 -- Tcl Markdown Server
  Root:  /home/greg/.../sites/tcltk/md
  Theme: hell
  HTTP:  http://localhost:8080/
Press Ctrl+C to stop.
```

Browser öffnen: **http://localhost:8080/**

### Clean URLs

Der mdserver unterstützt Clean URLs — SEE ALSO-Links ohne `.md`-Endung
werden automatisch aufgelöst:

```
/dict    → dict.md    ✅
/array   → array.md   ✅
```

Deshalb funktioniert `--linkmode server` direkt.

---

## Was der mdserver anzeigt

### Index-Seite (`/`)

Da `index.md` vorhanden ist, zeigt der Server diese statt der automatischen
Dateiliste. Die `index.md` enthält:

- Drei Kategorien: **Tcl Commands**, **Tk Commands**, **C API**
- Alphabetische Sprungmarken: `[A](#tcl-a) | [B](#tcl-b) | ...`
- Links zu allen 425 Seiten als `/pagename`

### Einzelne Seite

Jede Manpage wird als HTML gerendert mit:

- `[<< Index](index.md)` als Zurück-Navigation
- H1-Überschrift aus `.TH` (Seitenname)
- H2-Abschnitte aus `.SH` (NAME, SYNOPSIS, DESCRIPTION, ...)
- H3-Abschnitte aus `.SS`
- Code-Blöcke aus `.CS`/`.CE` und `.nf`/`.fi`
- Definition-Listen aus `.TP` (korrekt getrennt, auch wenn Term und
  Beschreibung auf einer Zeile stehen)
- SEE ALSO als klickbare Links zu anderen Seiten

---

## Einzelne Datei konvertieren

```bash
# Ausgabe auf stdout
tclsh tools/nroff2md.tcl tcltkdoc/tcl9.0/doc/dict.n

# In Datei schreiben
tclsh tools/nroff2md.tcl tcltkdoc/tcl9.0/doc/dict.n sites/tcltk/md/dict.md

# Aus stdin
cat tcltkdoc/tcl9.0/doc/dict.n | tclsh tools/nroff2md.tcl -
```

---

## Manpages aktualisieren

Wenn eine neue Tcl/Tk-Version erscheint:

```bash
# Altes md-Verzeichnis leeren
rm sites/tcltk/md/*.md

# Neu konvertieren
tclsh tools/nroff2md.tcl \
  --batch tcltkdoc/ \
  sites/tcltk/md/ \
  --linkmode server
```

Der mdserver muss dafür nicht neu gestartet werden — er liest `.md`-Dateien
bei jedem Request frisch vom Dateisystem.

---

## Automatischer Start-Wrapper

```bash
#!/bin/bash
# start-tcldoc.sh
cd /home/greg/Project/2026/code/markdown/site
exec tclsh mdserver.tcl \
  --root sites/tcltk/md/ \
  --port 8080
```

```bash
chmod +x start-tcldoc.sh
./start-tcldoc.sh
```

---

## Bekannte Einschränkungen

**C-API-Manpages (`.3`-Dateien):** C-Code-Blöcke werden mit `-lang tcl`
markiert. Für reine C-API-Konvertierung:

```bash
tclsh tools/nroff2md.tcl --batch tcltkdoc/tcl9.0/doc/ sites/tcltk/md/ -lang c
```

**Tabs in Tabellen:** Das `.SO`-Makro erzeugt tab-separierte Layouts,
die als Freitext gerendert werden, nicht als Markdown-Tabellen.
Betrifft Tk-Widget-Optionsseiten.

---

## Siehe auch

- `tools/nroff2md.tcl` — Konverter mit eingebetteten Modulen `nroffparser-0.2`
  und `ast2md-0.1`
- `mdserver.tcl` — HTTP-Server, lädt `lib/mdserver-0.1.tm`
- `man-viewer` — Tcl/Tk-Applikation zum Lesen von Manpages direkt als nroff
