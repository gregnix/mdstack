# mdserver Demo Site

Willkommen bei der **mdserver** Demo-Site.
Ein reiner Tcl-Web-Server ohne Tk -- Markdown wird on-the-fly als HTML ausgeliefert.

## Features

- Markdown-Dateien werden direkt als HTML gerendert
- Drei Themes waehlbar: [hell](?theme=hell), [dunkel](?theme=dunkel), [solarized](?theme=solarized)
- Verzeichnis-Index mit automatischer Dateiliste
- Statische Dateien (CSS, Bilder, JS)
- HTTP immer aktiv, HTTPS optional mit TLS-Zertifikat
- Kein Tk, kein Display, keine Fonts noetig

## Dokumentation

- [API-Referenz](api/index.md)
- [Anleitungen](guides/index.md)
- [Markdown-Features](features.md)

## Schnellstart HTTP

```bash
tclsh mdserver.tcl --root docs/ --port 8080 --theme hell
```

Dann im Browser: `http://localhost:8080`

## Schnellstart HTTPS

Zertifikat erzeugen (einmalig):

```bash
openssl req -x509 -newkey rsa:4096 -keyout server.key \
            -out server.crt -days 365 -nodes \
            -subj "/CN=localhost"
```

Server mit HTTPS starten:

```bash
tclsh mdserver.tcl --cert server.crt --key server.key
```

Erreichbar auf:
- `http://localhost:8080` (HTTP)
- `https://localhost:8443` (HTTPS)

TLS-Paket installieren falls noetig:

```bash
apt install tcl-tls
```

## Theme wechseln

Theme-Wechsel via URL-Parameter -- kein Neustart noetig:

- [?theme=hell](?theme=hell) -- Helles Standard-Theme
- [?theme=dunkel](?theme=dunkel) -- Dunkles Theme
- [?theme=solarized](?theme=solarized) -- Solarized Light

---

*Erstellt mit mdstack 2.0 + mdhtml 0.1 + mdtheme 0.1*
