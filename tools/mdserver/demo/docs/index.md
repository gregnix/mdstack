# mdserver Demo Site

Willkommen bei der **mdserver** Demo-Site.
Ein reiner Tcl-Web-Server ohne Tk -- Markdown wird on-the-fly als HTML ausgeliefert.

## Features

- Markdown-Dateien werden direkt als HTML gerendert
- **Nebenlaeufig** (Coroutine pro Verbindung) -- mehrere Nutzer gleichzeitig,
  slow-loris-fest
- Drei Themes: [hell](?theme=hell), [dunkel](?theme=dunkel), [solarized](?theme=solarized)
- **TOC-Stile**: [plain](?style=plain), [sidebar](?style=sidebar), [sticky](?style=sticky), [collapsible](?style=collapsible)
- **Navigation**: feste Leiste (Start / Alle Dokumente), Gesamt-Index aller Dokumente
- **Range** (206) fuer grosse Dateien, **Conditional GET** (304) fuers Caching
- HTTP immer aktiv, HTTPS optional mit TLS-Zertifikat
- **Control-Port** zum sauberen Beenden
- Kein Tk, kein Display, keine Fonts noetig

## Dokumentation

- [API-Referenz](api/index.md)
- [Anleitungen](guides/index.md)
- [Markdown-Features](features.md)

## TOC-Stil ausprobieren

Der Stil des Inhaltsverzeichnisses laesst sich per URL-Parameter umschalten
-- ohne Neustart:

- [?style=plain](?style=plain) -- Block oben (Standard)
- [?style=sidebar](?style=sidebar) -- feste Sidebar links
- [?style=sticky](?style=sticky) -- klebt oben am Rand
- [?style=collapsible](?style=collapsible) -- einklappbar

Oder als Server-Default: `tclsh mdserver.tcl --root docs --style sidebar`

## Navigation

Oben auf jeder Seite liegt eine Navi-Leiste:

- **Start** fuehrt zur Startseite (dieser `index.md`)
- **Alle Dokumente** ([?nav=index](?nav=index)) zeigt einen Baum **aller** `.md`

## Schnellstart HTTP

```bash
tclsh mdserver.tcl --root docs/ --port 8080 --theme hell
```

Dann im Browser: `http://localhost:8080`

## Schnellstart HTTPS

```bash
# Zertifikat erzeugen (einmalig)
tclsh mkcert.tcl --cn localhost

# Server mit HTTP + HTTPS
tclsh mdserver.tcl --cert server.crt --key server.key
```

Erreichbar auf `http://localhost:8080` und `https://localhost:8443`.
TLS-Paket falls noetig: `apt install tcl-tls`.

## Theme wechseln

- [?theme=hell](?theme=hell) -- Helles Standard-Theme
- [?theme=dunkel](?theme=dunkel) -- Dunkles Theme
- [?theme=solarized](?theme=solarized) -- Solarized Light

---

*Ausgeliefert mit mdstack (parser/html/theme) -- reiner Tcl-Stack, dual 8.6/9.*
