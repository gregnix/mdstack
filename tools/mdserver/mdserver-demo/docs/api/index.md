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
| `--theme` | `hell` | Standard-Theme |
| `--title` | `mdserver` | Site-Titel |
| `--toc` | `1` | Inhaltsverzeichnis |
| `--no-log` | -- | Logging deaktivieren |
| `--cert` | `""` | TLS-Zertifikat-Datei (.crt/.pem) |
| `--key` | `""` | TLS-Private-Key-Datei (.key) |
| `--tlsport` | `8443` | HTTPS-Port |

### HTTPS aktivieren

```bash
# Selbstsigniertes Zertifikat erzeugen (einmalig)
openssl req -x509 -newkey rsa:4096 -keyout server.key \
            -out server.crt -days 365 -nodes \
            -subj "/CN=localhost"

# Server mit HTTP + HTTPS starten
tclsh mdserver.tcl --cert server.crt --key server.key

# Anderer HTTPS-Port
tclsh mdserver.tcl --cert server.crt --key server.key --tlsport 443
```

Voraussetzung: `apt install tcl-tls`

Ohne TLS-Paket oder ohne `--cert`/`--key`: nur HTTP aktiv.

### URL-Parameter

Theme und TOC koennen per URL-Parameter ueberschrieben werden:

```
http://localhost:8080/doc.md?theme=dunkel
https://localhost:8443/doc.md?theme=hell&toc=0
```

### Routing

| URL | Verhalten |
|-----|-----------|
| `/` | `index.md` oder Verzeichnis-Listing |
| `/datei.md` | Markdown -> HTML |
| `/datei.txt` | Statische Datei |
| `/bild.png` | Statische Datei |

---

- [Anleitungen](../guides/index.md)
- [Startseite](../index.md)
