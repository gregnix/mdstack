# Markdown Features

Diese Seite demonstriert alle von mdhtml unterstuetzten Markdown-Elemente.

## Textformatierung

**Fett**, *kursiv*, ***fett und kursiv***, ~~durchgestrichen~~.

`Inline-Code` mit Monospace-Font.

## Links und Bilder

Einfacher Link: [Tcl/Tk Homepage](https://www.tcl.tk)

Link mit Titel: [GitHub](https://github.com/gregnix/pdf4tcl "pdf4tcl Fork")

Mehrere Links: Besuche [SourceForge](https://sourceforge.net/projects/pdf4tcl/)
oder [GitHub](https://github.com/gregnix/pdf4tcl) fuer den Quellcode.

## Blockquote

> Dies ist ein wichtiges Zitat mit **fettem** und *kursivem* Text.
>
> Zweiter Absatz im Zitat.
>
> > Verschachteltes Zitat zweiter Ebene.

## Code-Bloecke

```tcl
package require mdhtml 0.1
package require mdtheme 0.1

set ast  [mdparser::parse $markdown]
set html [mdhtml::render $ast -theme hell -toc 1]
mdhtml::export $ast output.html -theme dunkel -css custom.css
```

```bash
tclsh mdserver.tcl --port 8080 --root docs/ --theme dunkel
```

## Listen

Unsortiert:

- Erstes Element
- **Zweites Element** mit Formatierung
- Element mit [Link](https://tcl.tk)
  - Untergeordnet A
  - Untergeordnet B

Sortiert:

1. Erster Punkt
2. Zweiter Punkt
3. Dritter Punkt

Aufgabenliste:

- [x] mdparser (fertig)
- [x] mdhtml (fertig)
- [x] mdtheme (fertig)
- [x] mdserver (fertig)
- [ ] Syntax-Highlighting (geplant)

## Tabelle

| Modul | Version | Funktion |
|-------|---------|----------|
| mdparser | 0.2 | Markdown -> AST |
| mdhtml | 0.1 | AST -> HTML |
| mdtheme | 0.1 | Theme-System |
| mdpdf | 0.2 | AST -> PDF |
| mdviewer | 0.3 | AST -> Tk |
| mdserver | 0.1 | Markdown-Web-Server |

Tabelle mit Ausrichtung:

| Links | Zentriert | Rechts |
|:------|:---------:|-------:|
| Text  |  Mitte    |  42.00 |
| Lang  |  Kurz     |   1.50 |

## Definitionsliste

mdserver
: Markdown-Web-Server in pure Tcl, kein Tk noetig.

mdhtml
: Wandelt Markdown-AST in sauberes HTML um.

mdtheme
: Gemeinsames Theme-System fuer HTML, PDF und Tk.

## Horizontale Linie

---

## TIP-700 Spans

Befehl [proc]{.cmd}, Argument [filename]{.arg}, Literal [42]{.lit}.

## Fussnoten

Ein Text mit Fussnote[^1] und weiterer Referenz[^note].

[^1]: Erste Fussnote.
[^note]: Zweite Fussnote mit mehr Text.

---

*Ende der Feature-Uebersicht.*
