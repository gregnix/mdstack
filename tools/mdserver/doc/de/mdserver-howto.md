# Doku-Site mit mdserver aufbauen

Kurzanleitung: Von null zu einer laufenden Dokumentations-Site.

---

## Minimale Verzeichnisstruktur

```
meinprojekt/
  docs/
    index.md          <- Startseite (Pflicht)
    einleitung.md
    api/
      index.md
    guides/
      index.md
  tools/
    mdserver/
      lib/
        mdserver-0.1.tm
      mdserver.tcl
      mkcert.tcl
      start.tcl         <- optional, bequemer Starter
```

`docs/` ist der Document Root -- alles darunter wird serviert.
`tools/mdserver/` enthält den Server -- getrennt von den Inhalten.

---

## 1. Starten (HTTP)

```bash
cd meinprojekt/tools/mdserver
tclsh mdserver.tcl --root ../../docs --port 8080
```

Dann: `http://localhost:8080/`

Oder mit Titelangabe:

```bash
tclsh mdserver.tcl --root ../../docs --title "Mein Projekt" --theme hell
```

---

## 2. index.md als Startseite

Jedes Verzeichnis das eine `index.md` enthält zeigt diese automatisch.
Ohne `index.md` erscheint ein automatisches Verzeichnis-Listing.

Empfohlene `docs/index.md`:

```markdown
# Projektname

Kurze Beschreibung.

## Inhalt

- [Einleitung](einleitung.md)
- [API-Referenz](api/index.md)
- [Anleitungen](guides/index.md)
```

---

## 3. Navigation zwischen Seiten

Normale Markdown-Links -- relativ zum aktuellen Dokument:

```markdown
[Zurück zur Startseite](../index.md)
[API-Referenz](../api/index.md)
[Nächste Seite](schritt2.md)
```

mdserver liefert `.md`-Dateien als HTML aus -- die `.md`-Endung
im Link ist korrekt und nötig.

---

## 4. Verzeichnis-Index nutzen

Verzeichnisse ohne `index.md` zeigen automatisch alle `.md`-Dateien
mit Titel (aus der ersten `# Überschrift`) und Unterverzeichnisse.

Empfehlung: Für Hauptbereiche immer eine `index.md` anlegen.
Für flache Sammlungen (z.B. `recipes/`) reicht das Auto-Listing.

---

## 5. Statische Dateien

CSS, Bilder, JS liegen einfach im `docs/`-Verzeichnis:

```
docs/
  images/
    screenshot.png
  custom.css
```

Einbinden in Markdown:

```markdown
![Screenshot](images/screenshot.png)
```

Unterstützte Typen: `.css`, `.js`, `.png`, `.jpg`, `.gif`,
`.svg`, `.ico`, `.pdf`.

---

## 6. Theme wählen

Via `--theme` beim Start oder per URL-Parameter zur Laufzeit:

```bash
tclsh mdserver.tcl --root ../../docs --theme dunkel
```

Oder im Browser ohne Neustart:
```
http://localhost:8080/?theme=dunkel
http://localhost:8080/api/index.md?theme=solarized
http://localhost:8080/index.md?theme=hell&toc=0
```

Verfügbare Themes: `hell` (Standard), `dunkel`, `solarized`.

---

## 7. Inhaltsverzeichnis steuern

TOC wird automatisch aus den Überschriften generiert:

```bash
tclsh mdserver.tcl --root ../../docs --toc 1   # an (Standard)
tclsh mdserver.tcl --root ../../docs --toc 0   # aus
```

Oder per URL: `?toc=0`

---

## 8. start.tcl -- bequemer Starter

Für das eigene Projekt eine `start.tcl` neben `mdserver.tcl` anlegen:

```tcl
#!/usr/bin/env tclsh
# start.tcl -- Projekt-Doku starten

set scriptDir [file dirname [file normalize [info script]]]
set docsDir   [file normalize [file join $scriptDir ../../docs]]

set mdserverScript [file join $scriptDir mdserver.tcl]

puts "Projekt-Doku"
puts "  Docs: $docsDir"
puts "  HTTP: http://localhost:8080/"
puts ""

exec tclsh $mdserverScript \
    --root  $docsDir \
    --title "Mein Projekt" \
    --theme hell \
    --port  8080 \
    >@stdout 2>@stderr
```

Starten:
```bash
tclsh start.tcl
```

---

## 9. HTTPS (optional)

Zertifikat erzeugen (einmalig, mit `mkcert.tcl`):

```bash
tclsh mkcert.tcl
# erzeugt server.crt + server.key im aktuellen Verzeichnis
```

Server mit HTTPS:

```bash
tclsh mdserver.tcl \
    --root  ../../docs \
    --cert  server.crt \
    --key   server.key
```

Erreichbar auf:
- `http://localhost:8080`
- `https://localhost:8443`

`.gitignore` ergänzen:
```
tools/mdserver/server.crt
tools/mdserver/server.key
```

---

## 10. Troubleshooting

**Port belegt:**
```bash
fuser -k 8080/tcp
```

**mdserver-0.1.tm nicht gefunden:**
```
ERROR: mdserver 0.1 nicht gefunden
```
→ `lib/mdserver-0.1.tm` muss neben `mdserver.tcl` in `lib/` liegen.

**Seite zeigt nur Quelltext:**
→ Dateiendung muss `.md` sein, nicht `.txt` oder `.markdown`.

**Umlaute falsch:**
→ Markdown-Dateien müssen UTF-8 sein (Standard in jedem modernen Editor).

---

## Empfohlene Struktur für größere Projekte

```
docs/
  index.md              <- Startseite + Übersicht
  changelog.md
  einleitung/
    index.md            <- Bereich-Startseite
    installation.md
    konfiguration.md
  api/
    index.md
    klassen.md
    beispiele.md
  guides/
    index.md
    schnellstart.md
    fortgeschritten.md
```

Tiefe von 2-3 Ebenen reicht für die meisten Projekte.
Flache Struktur ist besser navigierbar als tief verschachtelte.

---

## Siehe auch

- [mdserver Referenz](mdserver.md)
- [mkcert.tcl Referenz](mdserver.md#mkcerttcl)
