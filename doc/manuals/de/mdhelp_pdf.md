# mdhelp_pdf

> **API reference:** [English version](../en/mdhelp_pdf.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


Widget-basierter PDF-Export fuer mdstack 2.0.

## Uebersicht

mdhelp_pdf exportiert den Inhalt eines gerenderten Tk Text-Widgets als PDF.
Im Gegensatz zu mdpdf (AST-basiert) arbeitet mdhelp_pdf mit dem fertigen
Widget-Inhalt und erfasst dadurch Frame-Tabellen, eingebettete Bilder und
Heading-Formatierung aus dem Viewer.

Version 0.3 delegiert die PDF-Erzeugung an pdf4tcllib.

## Abhaengigkeiten

- pdf4tcl (PDF-Basis)
- pdf4tcllib 0.1 (Fonts, Unicode, Text, Tabellen)
- Tk (fuer Widget-Zugriff)

## API

### available

```tcl
mdhelp_pdf::available
```

Gibt 1 zurueck wenn pdf4tcl verfuegbar ist.

### exportFromWidget

```tcl
set pages [mdhelp_pdf::exportFromWidget $textWidget $outFile ?options?]
```

Exportiert den Inhalt eines Text-Widgets als PDF.

Optionen:

- `-title ""` -- Titel auf erster Seite
- `-pagesize A4` -- Seitengroesse (A4, Letter)
- `-landscape 0` -- Querformat
- `-margin 50` -- Rand in Punkten
- `-fontsize 11` -- Basis-Schriftgroesse
- `-fontdir ""` -- Verzeichnis mit TTF-Dateien
- `-debug 0` -- Debug-Ausgaben

### exportFromFile

```tcl
set pages [mdhelp_pdf::exportFromFile $mdFile $outFile ?options?]
```

Exportiert eine Markdown-Datei direkt als PDF. Gleiche Optionen wie exportFromWidget.

## Beispiel

```tcl
package require mdhelp_pdf 0.3

# Von Widget exportieren
set pages [mdhelp_pdf::exportFromWidget .viewer.text "output.pdf" \
    -title "Handbuch" \
    -landscape 0 \
    -fontsize 11]

puts "$pages Seiten geschrieben"
```

## Migration von 0.2

Die API ist unveraendert. Intern werden 14 Funktionen durch
pdf4tcllib-Aufrufe ersetzt (1513 -> 627 Zeilen).
