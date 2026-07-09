# Anleitungen

## Schnellstart HTTP

```bash
tclsh mdserver.tcl --root /pfad/zu/docs --port 8080
```

## TOC-Stil waehlen

Das Inhaltsverzeichnis kann als Block (Default), feste Sidebar, sticky oder
einklappbar dargestellt werden:

```bash
# Server-Default
tclsh mdserver.tcl --root docs --style sidebar
```

Pro Seite per URL: `.../doc.md?style=sidebar`. Die CSS-Stile liegen in
`styles/` neben `lib/`; anderer Ort per `--stylesdir`.

## Navigation

Auf jeder Seite liegt oben eine Navi-Leiste (**Start** / **Alle Dokumente**).
Der Gesamt-Index `?nav=index` listet alle `.md` rekursiv als Baum.

Farben der Leiste anpassen:

```bash
tclsh mdserver.tcl --root docs --navbg "#800000" --navfg "#ffdd00"
```

## Sauberes Beenden (Control-Port)

```bash
tclsh mdserver.tcl --root docs --control 8099
echo stop | nc localhost 8099
```

So muss der Prozess nicht per `fuser -k` beendet werden.

## Schnellstart HTTPS

```bash
apt install tcl-tls
tclsh mkcert.tcl --cn localhost
tclsh mdserver.tcl --cert server.crt --key server.key
```

Selbstsigniert testen: `curl -k https://localhost:8443/`.
Fuer oeffentliche Server Let's Encrypt + Reverse Proxy.

## index.md als Startseite

Jedes Verzeichnis kann eine `index.md` haben, die automatisch als Startseite
angezeigt wird -- sonst erscheint ein Verzeichnis-Listing.

## Statische Dateien

`.css`, `.js`, `.png`, `.jpg`, `.gif`, `.svg`, `.pdf` werden direkt ausgeliefert
(mit Range/Conditional-GET).

---

- [API-Referenz](../api/index.md)
- [Startseite](../index.md)
