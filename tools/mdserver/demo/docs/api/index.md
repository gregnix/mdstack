# API-Referenz

## mdserver

### Kommandozeile

```bash
tclsh mdserver.tcl [Optionen]
```

| Option | Standard | Beschreibung |
|--------|----------|-------------|
| `--port` | `8080` | HTTP-Port |
| `--root` | `.` | Dokument-Wurzel |
| `--theme` | `hell` | Theme: hell, dunkel, solarized |
| `--style` | `plain` | TOC-Stil: plain, sidebar, sticky, collapsible |
| `--stylesdir` | `../styles` | Verzeichnis der CSS-Stile |
| `--title` | `mdserver` | Site-Titel |
| `--toc` | `1` | Inhaltsverzeichnis (0/1) |
| `--control` | `""` | Control-Port (localhost; stop/ping) |
| `--navbg` | `#2c3e50` | Navi-Leiste Hintergrundfarbe |
| `--navfg` | `#ffffff` | Navi-Leiste Textfarbe |
| `--no-log` | -- | Logging deaktivieren |
| `--cert` | `""` | TLS-Zertifikat (.crt/.pem) |
| `--key` | `""` | TLS-Private-Key (.key) |
| `--tlsport` | `8443` | HTTPS-Port |

### HTTPS aktivieren

```bash
tclsh mkcert.tcl --cn localhost
tclsh mdserver.tcl --cert server.crt --key server.key
```

Voraussetzung: `apt install tcl-tls`. Ohne `--cert`/`--key`: nur HTTP.

### Control-Port

```bash
tclsh mdserver.tcl --root docs --control 8099
echo stop | nc localhost 8099     # sauber beenden
echo ping | nc localhost 8099     # -> pong
```

### URL-Parameter

| Parameter | Werte | Wirkung |
|-----------|-------|---------|
| `?theme=` | hell, dunkel, solarized | Theme pro Seite |
| `?toc=` | 0, 1 | Inhaltsverzeichnis an/aus |
| `?style=` | plain, sidebar, sticky, collapsible | TOC-Stil pro Seite |
| `?nav=index` | -- | Gesamt-Index aller Dokumente |

```
http://localhost:8080/doc.md?theme=dunkel
http://localhost:8080/doc.md?style=sidebar
http://localhost:8080/?nav=index
```

### HTTP-Features

- **Range (206)**: `Range: bytes=0-99` -- grosse PDFs/Bilder springbar.
- **Conditional GET (304)**: `If-Modified-Since` -- unveraenderte Dateien nicht neu.

### Routing

| URL | Verhalten |
|-----|-----------|
| `/` | `index.md` oder Verzeichnis-Listing |
| `/datei.md` | Markdown -> HTML |
| `/datei` | Clean URL: versucht `/datei.md` |
| `/bild.png`, `/doc.pdf` | Statische Datei (mit Range/304) |

---

- [Anleitungen](../guides/index.md)
- [Startseite](../index.md)
