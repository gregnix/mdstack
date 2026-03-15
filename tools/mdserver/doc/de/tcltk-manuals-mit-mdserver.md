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
  src/tcl9.0.3/doc/*.n      nroff-Quellformat
  src/tk9.0.3/doc/*.n       nroff-Quellformat
        |
        v nroff2md.tcl --batch
  sites/tcltk/md/*.md       Markdown
        |
        v mdserver.tcl
  http://localhost:8080/    Browser
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
    nroff2md.tcl        Konverter
  sites/
    tcltk/
      md/               Konvertierte Manpages (wird erzeugt)
  mdserver.tcl          Server
```

---

## Schritt 2: Manpages konvertieren

### Tcl-Manpages

```bash
tclsh tools/nroff2md.tcl \
  --batch src/tcl9.0.3/doc/ \
  sites/tcltk/md/
```

Ausgabe (Auszug):

```
Written: sites/tcltk/md/dict.md
Written: sites/tcltk/md/chan.md
Written: sites/tcltk/md/string.md
...
Converted: 248  Failed: 0  Total: 248
```

### Tk-Manpages (optional, zusätzlich)

```bash
tclsh tools/nroff2md.tcl \
  --batch src/tk9.0.3/doc/ \
  sites/tcltk/md/
```

Die Ausgabe landet im selben Verzeichnis. Namenskonflikte gibt es nicht, da die
Dateinamen eindeutig sind.

### Mit expliziter Codesprache

Standardmäßig verwendet `nroff2md` `tcl` als Sprache für Code-Blöcke. Das ist
für alle Tcl/Tk-Manpages korrekt:

```bash
tclsh tools/nroff2md.tcl \
  --batch src/tcl9.0.3/doc/ \
  sites/tcltk/md/ \
  -lang tcl
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

---

## Was der mdserver anzeigt

### Index-Seite (`/`)

Die Startseite zeigt alle konvertierten Manpages mit verlinkten Titeln, sortiert
alphabetisch. Titel werden aus dem `.TH`-Makro des nroff-Originals gewonnen —
das ergibt lesbare Namen wie *dict*, *chan*, *string* statt Dateinamen.

### Einzelne Seite

Jede Manpage wird als HTML gerendert mit:

- H1-Überschrift aus `.TH` (Seitenname)
- H2-Abschnitte aus `.SH` (NAME, SYNOPSIS, DESCRIPTION, EXAMPLES, ...)
- H3-Abschnitte aus `.SS`
- Fettdruck für Befehlsnamen (`\fB...\fR`)
- Kursiv für Argumente (`\fI...\fR`)
- Code-Blöcke aus `.nf`/`.fi` und `.CS`/`.CE`
- Definition-Listen aus `.TP` (Befehlsoptionen, Schlüsselwörter)

---

## Einzelne Datei konvertieren

Für schnelle Tests oder die Konvertierung einzelner Seiten:

```bash
# Ausgabe auf stdout
tclsh tools/nroff2md.tcl src/tcl9.0.3/doc/dict.n

# In Datei schreiben
tclsh tools/nroff2md.tcl src/tcl9.0.3/doc/dict.n sites/tcltk/md/dict.md

# Aus stdin
cat src/tcl9.0.3/doc/dict.n | tclsh tools/nroff2md.tcl -
```

---

## Manpages aktualisieren

Wenn eine neue Tcl/Tk-Version erscheint, reicht ein erneuter Batch-Lauf:

```bash
# Altes md-Verzeichnis leeren
rm sites/tcltk/md/*.md

# Neu konvertieren
tclsh tools/nroff2md.tcl --batch src/tcl9.0.4/doc/ sites/tcltk/md/
```

Der mdserver muss dafür nicht neu gestartet werden — er liest `.md`-Dateien
bei jedem Request frisch vom Dateisystem.

---

## Bekannte Einschränkungen

**TP-Listen mit verketteten Einträgen:** In einigen Manpages (z.B. `chan.n`)
stehen mehrere `.TP`-Einträge direkt hintereinander ohne trennende `.PP`-Makros.
Der aktuelle nroff2md-Renderer fasst die Einträge korrekt zusammen, aber
aufeinanderfolgende Terme können ohne Zwischenzeile gerendert werden. An einem
Fix wird gearbeitet.

**C-API-Manpages (`.3`-Dateien):** Die C-API-Seiten (z.B. `CrtChannel.3`,
`DString.3`) enthalten häufig C-Code-Blöcke. Diese werden mit `-lang tcl`
markiert, was nicht optimal ist. Mit `-lang c` wäre es besser:

```bash
# Nur C-API-Seiten mit -lang c konvertieren
tclsh tools/nroff2md.tcl --batch src/tcl9.0.3/doc/ sites/tcltk/md/c-api/ -lang c
```

**Tabs in Tabellen:** Das `.SO`-Makro (Standard-Optionen) erzeugt
tab-separierte Layouts, die als Freitext-Absätze gerendert werden, nicht als
Markdown-Tabellen. Betrifft vor allem Tk-Widget-Optionsseiten.

---

## Automatischer Start-Wrapper

Für den täglichen Gebrauch empfiehlt sich ein kleines Start-Script:

```bash
#!/bin/bash
# start-tcldoc.sh
cd /home/greg/Project/2026/code/markdown/site
exec tclsh mdserver.tcl \
  --root sites/tcltk/md/ \
  --port 8080
```

Aufruf:

```bash
chmod +x start-tcldoc.sh
./start-tcldoc.sh
```

---

## Siehe auch

- `tools/nroff2md.tcl` — Konverter mit eingebetteten Modulen `nroffparser-0.2`
  und `ast2md-0.1`
- `mdserver.tcl` — HTTP-Server, lädt `lib/mdserver-0.1.tm`
- `man-viewer` — Tcl/Tk-Applikation zum Lesen von Manpages direkt als nroff
