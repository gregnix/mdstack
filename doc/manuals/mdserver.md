# mdserver

> Version 0.2

## Zweck

`mdserver` ist ein HTTP/HTTPS-Web-Server in pure Tcl (kein Tk).
Er liefert Markdown-Dateien on-the-fly als HTML aus.

- Kein Tk, kein Display, keine Fonts noetig
- HTTP immer aktiv, HTTPS optional mit TLS-Zertifikat
- Theme-Auswahl via URL-Parameter
- Statische Dateien direkt ausgeliefert
- Verzeichnis-Index mit automatischer Dateiliste

**Speicherort:** `tools/mdserver/mdserver.tcl`

---

## Abhaengigkeiten

| Paket | Version | Pflicht |
|-------|---------|---------|
| `mdparser` | 0.2 | ja |
| `mdhtml` | 0.1 | ja |
| `mdtheme` | 0.1 | empfohlen |
| `tls` | -- | nur fuer HTTPS |

```bash
# tls installieren (Debian/Ubuntu)
apt install tcl-tls
```

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
| `--title` | `mdserver` | Site-Titel |
| `--toc` | `1` | Inhaltsverzeichnis (0 oder 1) |
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
```

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

Ohne `--cert`/`--key` laeuft nur HTTP -- kein Fehler.

### TLS-Sicherheit

Aktiv: TLS 1.2, TLS 1.3
Deaktiviert: SSL2, SSL3, TLS 1.0, TLS 1.1

---

## URL-Parameter

Theme und TOC koennen zur Laufzeit per URL geaendert werden
ohne den Server neu zu starten:

```
http://localhost:8080/doc.md?theme=dunkel
http://localhost:8080/doc.md?theme=solarized&toc=0
https://localhost:8443/index.md?theme=hell
```

---

## Routing

| URL | Verhalten |
|-----|-----------|
| `/` | `index.md` wenn vorhanden, sonst Verzeichnis-Listing |
| `/datei.md` | Markdown -> HTML |
| `/verzeichnis/` | `index.md` oder Verzeichnis-Listing |
| `.css`, `.js`, `.png`, `.jpg`, `.gif`, `.svg`, `.pdf` | Statische Datei |
| Nicht gefunden | 404-Seite |

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
[09:15:03] GET /favicon.ico
[09:15:03]   -> 404
```

Mit `--no-log` deaktivieren.

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
```

`start.tcl` ruft `mkcert.tcl` automatisch auf wenn kein
Zertifikat vorhanden oder das vorhandene abgelaufen ist.

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

Erkennt automatisch ob Zertifikat vorhanden und noch gueltig ist.

---

## .gitignore

```
tools/mdserver/server.crt
tools/mdserver/server.key
```

---

## Sicherheitshinweise

- **Directory Traversal** ist blockiert (safePath-Pruefung)
- **Selbstsignierte Zertifikate** zeigen Browser-Warnung -- nur fuer Entwicklung
- **Let's Encrypt** fuer oeffentliche Server empfohlen
- `mdserver` ist kein Produktions-HTTP-Server -- fuer Produktion
  Reverse Proxy (nginx, caddy) vorschalten

---

## Dateistruktur

```
tools/mdserver/
  mdserver.tcl          -- Web-Server
  mkcert.tcl            -- Zertifikat-Hilfsskript
  server.crt            -- (generiert, nicht im Git)
  server.key            -- (generiert, nicht im Git)
  test/
    test-mdserver.tcl   -- Test-Suite (47 Tests)
  mdserver-demo/
    start.tcl           -- Demo-Startskript
    docs/               -- Demo-Inhalt
      index.md
      features.md
      api/index.md
      guides/index.md
    static/             -- Statische Dateien
```

---

## Changelog

### 0.2 (2026-03-14)

- HTTPS via TLS-Paket (`--cert`, `--key`, `--tlsport`)
- TLS 1.2 + 1.3 aktiv, aeltere Versionen deaktiviert
- `mkcert.tcl` -- Zertifikatsverwaltung
- `start.tcl` -- automatische Zertifikatserzeugung via `--https`
- Zertifikat-Standardpfad: `tools/mdserver/` (nicht in Demo-Site)

### 0.1 (2026-03-14)

- Initiale Version
- HTTP-Server via `socket`
- Markdown -> HTML (mdhtml + mdtheme)
- Verzeichnis-Index
- URL-Parameter: `?theme=`, `?toc=`
- Statische Dateien
- Directory Traversal blockiert
- 47 Tests in `test/test-mdserver.tcl`

---

## Siehe auch

- [mdhtml](mdhtml.md) -- HTML-Renderer
- [mdtheme](mdtheme.md) -- Theme-System
- [mdpdf](mdpdf.md) -- PDF-Renderer
