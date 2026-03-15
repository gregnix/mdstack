# Anleitungen

## Schnellstart HTTP

```bash
tclsh mdserver.tcl --root /pfad/zu/docs --port 8080
```

## Schnellstart HTTPS

### 1. TLS-Paket installieren

```bash
# Debian/Ubuntu
apt install tcl-tls

# macOS (Homebrew)
brew install tcl-tls
```

### 2. Zertifikat erzeugen

Selbstsigniert (fuer lokale Entwicklung):

```bash
openssl req -x509 -newkey rsa:4096 \
    -keyout server.key -out server.crt \
    -days 365 -nodes -subj "/CN=localhost"
```

Let's Encrypt (fuer oeffentliche Server):

```bash
certbot certonly --standalone -d example.com
# Ergebnis: /etc/letsencrypt/live/example.com/fullchain.pem
```

### 3. Server starten

```bash
# HTTP (8080) + HTTPS (8443)
tclsh mdserver.tcl --cert server.crt --key server.key

# Mit Let's Encrypt, Port 80 + 443
tclsh mdserver.tcl \
    --cert /etc/letsencrypt/live/example.com/fullchain.pem \
    --key  /etc/letsencrypt/live/example.com/privkey.pem \
    --port 80 --tlsport 443
```

Ohne `--cert`/`--key`: nur HTTP -- kein Fehler, kein Absturz.

## Theme anpassen

### Vordefinierte Themes

```bash
tclsh mdserver.tcl --theme hell
tclsh mdserver.tcl --theme dunkel
tclsh mdserver.tcl --theme solarized
```

### Eigene CSS-Overrides

Erstelle eine Datei `custom.css`:

```css
body { font-size: 14pt; max-width: 750px; }
h1   { color: #8b0000; }
```

Im Code (Theme als Basis + Overrides):

```tcl
set html [mdhtml::render $ast -theme hell -css custom.css]
```

## index.md als Startseite

Jedes Verzeichnis kann eine `index.md` haben die automatisch
als Startseite angezeigt wird -- andernfalls erscheint ein
Verzeichnis-Listing.

## Statische Dateien

Endungen `.css`, `.js`, `.png`, `.jpg`, `.gif`, `.svg`, `.pdf`
werden direkt ausgeliefert ohne Umwandlung.

---

- [API-Referenz](../api/index.md)
- [Startseite](../index.md)
