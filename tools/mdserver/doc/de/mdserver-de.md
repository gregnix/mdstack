# mdserver

> **API reference:** [English version](../en/mdserver.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


> Version 0.2 (Modul) -- nebenlaeufig (Coroutine), slow-loris-fest,
> Range/Conditional-GET, Control-Port, TOC-Stile.

## Zweck

`mdserver` ist ein HTTP/HTTPS-Web-Server in pure Tcl (kein Tk).
Er liefert Markdown-Dateien on-the-fly als HTML aus.

- Kein Tk, kein Display, keine Fonts noetig
- **Nebenlaeufig**: eine Coroutine pro Verbindung, non-blocking I/O --
  mehrere Nutzer gleichzeitig, ein langsamer Client blockiert die anderen nicht
- HTTP immer aktiv, HTTPS optional mit TLS-Zertifikat
- Theme- und **TOC-Stil-Auswahl** via URL-Parameter
- **Navigation**: Startseite, Gesamt-Index aller Dokumente, feste Navi-Leiste
- **Range-Requests (206)** -- grosse PDFs/Bilder im Browser springbar
- **Conditional GET (304)** -- unveraenderte Dateien werden nicht neu gesendet
- **Control-Port** -- sauberes Beenden ohne `fuser -k`
- Statische Dateien direkt ausgeliefert
- Verzeichnis-Index mit automatischer Dateiliste

**Speicherort:** `tools/mdserver/mdserver.tcl`, Modul `lib/mdserver-0.2.tm`

---

## Abhaengigkeiten

| Paket | Version | Pflicht |
|-------|---------|---------|
| `Tcl` | 8.6 oder 9 | ja |
| `mdstack::parser` | 0.2 | ja |
| `mdstack::html` | 0.1 | ja |
| `mdstack::theme` | 0.1 | empfohlen |
| `tls` | -- | nur fuer HTTPS |

```bash
# tls installieren (Debian/Ubuntu)
apt install tcl-tls
```

Dual-tauglich: laeuft unverandert unter Tcl/Tk **8.6 und 9.0**.

---

## Kommandozeile

```bash
tclsh mdserver.tcl [Optionen]
```

| Option | Standard | Beschreibung |
|--------|----------|-------------|
| `--port` | `8080` | HTTP-Port |
| `--root` | `.` | Dokument-Wurzel |
| `--theme` | `hell` | Theme: `hell`, `dunkel`, `solarized` |
| `--style` | `plain` | TOC-Stil: `plain`, `sidebar`, `sticky`, `collapsible` |
| `--stylesdir` | `../styles` | Verzeichnis der CSS-Stile |
| `--navbg` | `#2c3e50` | Navi-Leiste: Hintergrundfarbe |
| `--navfg` | `#ffffff` | Navi-Leiste: Textfarbe |
| `--title` | `mdserver` | Site-Titel |
| `--toc` | `1` | Inhaltsverzeichnis (0 oder 1) |
| `--control` | `""` | Control-Port (nur localhost; `stop`/`ping`) |
| `--no-log` | -- | Logging deaktivieren |
| `--cert` | `""` | TLS-Zertifikat (.crt/.pem) |
| `--key` | `""` | TLS-Private-Key (.key) |
| `--tlsport` | `8443` | HTTPS-Port |
| `--help` | -- | Hilfe anzeigen |

---

## HTTP-Betrieb

```bash
# Aktuelles Verzeichnis
tclsh mdserver.tcl

# Bestimmtes Verzeichnis
tclsh mdserver.tcl --root /pfad/zu/docs

# Anderer Port und Theme
tclsh mdserver.tcl --port 9000 --theme dunkel

# Mit Sidebar-TOC als Standard und Control-Port
tclsh mdserver.tcl --root docs --style sidebar --control 8099
```

---

## Nebenlaeufigkeit / LAN-Betrieb

Seit 0.2 bedient `mdserver` jede Verbindung in einer **eigenen Coroutine** mit
**nicht-blockierendem** Lesen/Schreiben. Das heisst:

- **Mehrere Nutzer gleichzeitig** -- kein Warten in der Schlange.
- **Slow-loris-fest**: ein Client, der sich verbindet und nichts (oder sehr
  langsam) sendet, blockiert den Server **nicht**; ein Lese-Timeout verwirft
  solche Verbindungen.
- **Grosse Dateien** blockieren die anderen Verbindungen nicht (non-blocking
  Ausgabe).

Damit ist der Server fuer den Einsatz im Firmen-LAN (mehrere Leser) geeignet.
Fuer oeffentliche Server weiterhin einen Reverse Proxy vorschalten (siehe
Sicherheitshinweise).

---

## TOC-Stile (`?style=`)

Das Inhaltsverzeichnis (`<nav class="toc">`) kann verschieden dargestellt werden
-- gesteuert ueber CSS-Stile, analog zum HTML-Export in **mdhelp**:

| Stil | Wirkung |
|------|---------|
| `plain` | Standard: TOC als Block oben (Default) |
| `sidebar` | TOC als feste Sidebar links, bleibt beim Scrollen sichtbar |
| `sticky` | TOC klebt oben am Fensterrand |
| `collapsible` | TOC einklappbar |

Pro Seite per URL:

```
http://localhost:8080/doc.md?style=sidebar
```

Oder als Standard fuer den ganzen Server:

```bash
tclsh mdserver.tcl --root docs --style sidebar
```

**Wichtig -- Speicherort der Stile:** die CSS-Dateien liegen per Default in
`styles/` **neben** `lib/` (also `tools/mdserver/styles/`):

```
tools/mdserver/
  lib/mdserver-0.2.tm
  styles/
    sidebar.css
    sticky-top.css
    collapsible.css
```

Liegt `styles/` woanders, den Pfad explizit setzen:

```bash
tclsh mdserver.tcl --root docs --style sidebar --stylesdir /pfad/zu/styles
```

Technisch: `mdserver` rendert die Seite und fuegt den gewaehlten Stil als
zusaetzlichen `<style>`-Block **hinter** dem Standard-CSS ein -- per
CSS-Kaskade gewinnen die Stil-Regeln. Fehlt die CSS-Datei, wird ohne Stil
ausgeliefert (kein Fehler).

---

## Navigation

`mdserver` blendet auf jeder Seite eine schmale **Navi-Leiste** oben ein und
bietet einen **Gesamt-Index** ueber alle Dokumente.

**Startseite** ist die `index.md` im Wurzelverzeichnis. Der Link **Start** in der
Leiste fuehrt immer dorthin (`/`).

**Gesamt-Index** ueber die Route **`?nav=index`**: listet rekursiv alle `.md`
unter der Wurzel als Baum (Titel aus dem ersten `# H1`, Verzeichnisse fett).
Erreichbar ueber den Link **Alle Dokumente**:

```
http://localhost:8080/?nav=index
```

**Navi-Leiste anpassen.** Farben per CLI, Links/Icons programmatisch:

```bash
tclsh mdserver.tcl --root docs --navbg "#800000" --navfg "#ffdd00"
```

```tcl
# eigene Links (Konstruktor): Liste von {label url}-Paaren,
# Icons als HTML-Entity im Label
mdserver::Server new -root docs -navlinks {
    {{&#127968; Start} /}
    {{&#128218; Alle Dokumente} /?nav=index}
    {{&#9881; Doku} /doc/}
}
```

Ausschalten mit der Config-Option `nav 0` (Konstruktor). Die Leiste wird nach
`<body>` eingefuegt und liegt ueber die volle Breite links; im Sidebar-Stil ist
sie eine feste Top-Leiste (`position: fixed`).

---

## Control-Port (sauberes Beenden)

Mit `--control PORT` oeffnet der Server einen **localhost-only** Steuerkanal:

```bash
tclsh mdserver.tcl --root docs --control 8099
```

Kommandos (eine Zeile):

```bash
echo stop | nc localhost 8099     # Server sauber beenden (Listener + offene
                                  # Verbindungen schliessen, dann Prozessende)
echo ping | nc localhost 8099     # -> pong
```

Das ist der empfohlene Weg zum Beenden eines dauerlaufenden Servers -- kein
`fuser -k`, keine PID-Suche.

---

## HTTPS-Betrieb

### 1. TLS-Paket installieren

```bash
apt install tcl-tls
```

### 2. Zertifikat erzeugen

Mit `mkcert.tcl` (liegt neben `mdserver.tcl`):

```bash
tclsh mkcert.tcl
tclsh mkcert.tcl --cn meinserver.local --days 730
```

Oder direkt mit `openssl`:

```bash
openssl req -x509 -newkey rsa:4096 \
    -keyout server.key -out server.crt \
    -days 365 -nodes -subj "/CN=localhost"
```

### 3. Server starten

```bash
# HTTP (8080) + HTTPS (8443)
tclsh mdserver.tcl --cert server.crt --key server.key

# Anderer HTTPS-Port
tclsh mdserver.tcl --cert server.crt --key server.key --tlsport 443

# Let's Encrypt
tclsh mdserver.tcl \
    --cert /etc/letsencrypt/live/example.com/fullchain.pem \
    --key  /etc/letsencrypt/live/example.com/privkey.pem \
    --port 80 --tlsport 443
```

Ohne `--cert`/`--key` laeuft nur HTTP -- kein Fehler. HTTPS wird nebenlaeufig
bedient (der TLS-Handshake laeuft ueber die non-blocking Coroutine).

Test mit selbstsigniertem Zertifikat: `curl -k https://localhost:8443/`
(`-k`, weil selbstsignierte Zertifikate nicht vertrauenswuerdig sind).

### TLS-Sicherheit

Aktiv: TLS 1.2, TLS 1.3
Deaktiviert: SSL2, SSL3, TLS 1.0, TLS 1.1

---

## URL-Parameter

Theme, TOC und TOC-Stil koennen zur Laufzeit per URL geaendert werden
ohne den Server neu zu starten:

```
http://localhost:8080/doc.md?theme=dunkel
http://localhost:8080/doc.md?theme=solarized&toc=0
http://localhost:8080/doc.md?style=sidebar
https://localhost:8443/index.md?theme=hell
```

---

## HTTP-Features fuer Dateien

Statische Dateien (PDF, Bilder, CSS, ...) werden mit Cache- und
Teilbereichs-Unterstuetzung ausgeliefert:

- **`Range` / 206 Partial Content**: `Range: bytes=0-99`, `bytes=1000-`,
  `bytes=-50` (letzte 50 Bytes); ungueltiger Bereich -> `416`. Mit
  `Accept-Ranges: bytes` und `Content-Range`. So sind grosse PDFs/Videos im
  Browser springbar.
- **`If-Modified-Since` / 304 Not Modified**: unveraenderte Dateien werden nicht
  neu gesendet (`Last-Modified` an allen Dateien).

---

## Routing

| URL | Verhalten |
|-----|-----------|
| `/` | `index.md` wenn vorhanden, sonst Verzeichnis-Listing |
| `/datei.md` | Markdown → HTML |
| `/datei` | Clean URL: versucht automatisch `/datei.md` |
| `/verzeichnis/` | `index.md` oder Verzeichnis-Listing |
| `.css`, `.js`, `.png`, `.jpg`, `.gif`, `.svg`, `.pdf` | Statische Datei |
| Nicht gefunden | 404-Seite |

**Clean URLs** erlauben Links ohne `.md`-Endung (z.B. `/dict`, `/array`).
Wird von `nroff2md --linkmode server` für SEE ALSO-Querverweise genutzt.

---

## Verzeichnis-Index

Wenn kein `index.md` vorhanden ist, erscheint ein automatisches
Verzeichnis-Listing mit:

- Unterverzeichnissen
- Markdown-Dateien (Titel aus erstem H1)
- Link zur uebergeordneten Ebene

---

## Logging

```
[09:15:03] GET /index.md
[09:15:03]   -> 200 (markdown)
[09:15:03] GET /handbuch.pdf
[09:15:03]   -> 206 (bytes 0-65535/2400000)
[09:15:03] GET /style.css
[09:15:03]   -> 304 (not modified)
```

Mit `--no-log` deaktivieren.

---

## Troubleshooting

### Port bereits belegt

```
ERROR: Cannot bind to HTTP port 8080: address already in use
```

Ein anderer Prozess (z.B. eine frueherer mdserver-Instanz) belegt den Port noch.
Am saubersten via Control-Port beenden (siehe oben). Sonst:

```bash
fuser -k 8080/tcp             # Port sofort freigeben
fuser 8080/tcp; kill <PID>    # erst nachschauen, dann beenden
lsof -ti:8080 | xargs kill    # Alternative
```

### `?style=sidebar` aendert nichts

Der Server findet die CSS-Stile nicht. Pruefen:

```bash
ls tools/mdserver/styles/     # sidebar.css etc. muessen da sein
```

Fehlen sie, `styles/` neben `lib/` ablegen oder `--stylesdir` setzen.

### HTTPS: `unexpected eof` bzw. `self-signed certificate`

- `unexpected eof`: HTTP-Port mit `https://` angesprochen -- Schema/Port pruefen.
- `self-signed certificate (18)`: Handshake ok, curl vertraut dem
  selbstsignierten Zertifikat nicht -> `curl -k`.

---

## Demo-Site

Unter `tools/mdserver/mdserver-demo/` liegt eine vollstaendige
Demo-Site mit Anleitungen und Feature-Uebersicht.

### Demo mit start.tcl starten

```bash
cd tools/mdserver/mdserver-demo

# HTTP only
tclsh start.tcl

# HTTP + HTTPS (Zertifikat wird automatisch erzeugt)
tclsh start.tcl --https

# Mit eigenem CN
tclsh start.tcl --https --cn meinserver.local

# Mit Sidebar-TOC und Control-Port
tclsh start.tcl --style sidebar --control 8099
```

`start.tcl` ruft `mkcert.tcl` automatisch auf wenn kein
Zertifikat vorhanden oder das vorhandene abgelaufen ist. Unbekannte Flags
(z.B. `--theme`) werden an `mdserver.tcl` durchgereicht.

---

## mkcert.tcl

Hilfsskript zur Zertifikatsverwaltung.

```bash
# Zertifikat erzeugen (Defaults: localhost, 365 Tage, 4096 Bit)
tclsh mkcert.tcl

# Mit Optionen
tclsh mkcert.tcl --cn example.com --days 730 --bits 2048

# Gueltigkeit pruefen (z.B. in Cron)
tclsh mkcert.tcl --check
```

| Option | Standard | Beschreibung |
|--------|----------|-------------|
| `--cn` | `localhost` | Common Name / Hostname |
| `--days` | `365` | Gueltigkeitsdauer |
| `--bits` | `4096` | RSA-Schluesselbits |
| `--out` | `.` | Ausgabeverzeichnis |
| `--cert` | `server.crt` | Zertifikat-Dateiname |
| `--key` | `server.key` | Key-Dateiname |
| `--check` | -- | Nur Gueltigkeit pruefen |

Erkennt automatisch ob Zertifikat vorhanden und noch gueltig ist. Fuers LAN den
`--cn` auf den Hostnamen/die IP des Servers setzen, sonst warnt der Browser.

---

## .gitignore

```
tools/mdserver/server.crt
tools/mdserver/server.key
```

---

## Sicherheitshinweise

- **Directory Traversal** ist blockiert (safePath-Pruefung)
- **Control-Port** bindet nur an `127.0.0.1` (nicht von aussen erreichbar)
- **Selbstsignierte Zertifikate** zeigen Browser-Warnung -- nur fuer Entwicklung
- **Let's Encrypt** fuer oeffentliche Server empfohlen
- `mdserver` eignet sich fuer Preview und LAN-Auslieferung; fuer den oeffentlichen
  Betrieb einen Reverse Proxy (nginx, caddy) vorschalten

---

## Dateistruktur

```
tools/mdserver/
  mdserver.tcl          -- Startskript (CLI)
  lib/
    mdserver-0.2.tm     -- Server-Modul
  styles/               -- TOC-CSS-Stile
    sidebar.css
    sticky-top.css
    collapsible.css
  mkcert.tcl            -- Zertifikat-Hilfsskript
  server.crt            -- (generiert, nicht im Git)
  server.key            -- (generiert, nicht im Git)
  test/
    test-mdserver-oo.tcl
  doc/                  -- Diese Dokumentation
  mdserver-demo/
    start.tcl           -- Demo-Startskript
    docs/               -- Demo-Inhalt
```

---

## Changelog

### 0.2 (2026-07-09)

- **Nebenlaeufig**: Coroutine pro Verbindung, non-blocking I/O
  (mehrere Nutzer gleichzeitig, slow-loris-fest, Lese-Timeout)
- **Range-Requests (206)** inkl. Suffix + 416, `Accept-Ranges`, `Content-Range`
- **Conditional GET (304)** via `Last-Modified` / `If-Modified-Since`
- **Control-Port** (`--control`): `stop`/`ping`, sauberes Herunterfahren
- **TOC-Stile** (`--style` / `?style=`): `sidebar`, `sticky`, `collapsible`
  (CSS aus `styles/`, wie mdhelps HTML-Export)
- **Navigation**: feste Navi-Leiste (Start / Alle Dokumente), Gesamt-Index
  `?nav=index`, konfigurierbar via `navbg`/`navfg`/`navlinks`
- TLS-Handshake nebenlaeufig; Handshake-Fehler kaputter Verbindungen werden
  still verworfen (kein Log-Rauschen)
- Tcl 9 (`package require Tcl 8.6 9`)

### 0.1 (aeltere Versionen)

- HTTP/HTTPS-Server (`socket` / `tls`), `--cert`/`--key`/`--tlsport`
- Markdown -> HTML (mdstack), Verzeichnis-Index
- URL-Parameter `?theme=`, `?toc=`
- Statische Dateien, Directory Traversal blockiert
- `mkcert.tcl`, `start.tcl`

---

## Siehe auch

- [mdhelp](../../mdhelp/README.md) -- Markdown-Hilfe-Viewer (gleiche TOC-Stile)
- mdstack -- Markdown-Pipeline (parser/html/theme)
