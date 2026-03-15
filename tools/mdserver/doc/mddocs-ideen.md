# mddocs -- Ideen: Dokumentations-Server fuer Tcl

Stand: 2026-03-15 (aktualisiert)
Status: Ideensammlung, kein Commitment

---

## Ausgangslage

`mdserver.tcl` (tools/mdserver in mdstack) ist ein einfacher
Markdown-Web-Server -- gut fuer lokale Dokumentation, aber ohne
Benutzer, Suche, Editieren oder Versionierung.

`mddocs` waere ein vollstaendiger Dokumentations-Server auf
Basis von mdstack -- aehnlich wie Gitea/Confluence, aber:
- pure Tcl, kein C, kein Java
- Markdown-nativ
- leichtgewichtig
- selbst gehostet

---

## Feature-Set

### Kern

| Feature | Beschreibung | Basis |
|---------|-------------|-------|
| Rendering | Markdown -> HTML on-the-fly | mdparser + mdhtml |
| Suche | Volltext ueber alle .md-Dateien | mdsearch |
| Themes | hell/dunkel/solarized + custom CSS | mdtheme |
| HTTP + HTTPS | TLS via tls-Paket | mdserver |
| Verzeichnis-Index | automatisch mit Titel aus H1 | mdserver |

### Editieren

- Bearbeiten lokal in **mdstack** (kein Browser-Editor)
- Fertig geschriebener Artikel wird als Ganzes per HTTP POST gesendet
- Server speichert + Git-Commit (automatisch)
- Konflikt-Erkennung: Git-Pull vor Speichern

### Versionierung

- Git als Backend -- jede Aenderung = Commit
- History anzeigen: wer hat wann was geaendert
- Diff-Ansicht zwischen Versionen
- Revert auf frueheren Stand

### Benutzerverwaltung

```
Gruppen:   admin / editor / reader
Rechte:    lesen / bearbeiten / loeschen / verwalten
Auth:      Session-Cookie (einfach) oder Basic Auth
Speicher:  SQLite (kein externer DB-Server noetig)
```

### Async

- Tcl Coroutinen fuer nicht-blockierende I/O
- `fconfigure -blocking 0` + `readable`-Event
- Kein Threading noetig

---

## Architektur

```
Browser
   |
mdserver-0.1.tm    (TclOO, async via Coroutine)
   |
+--------+--------+--------+--------+--------+
|        |        |        |        |        |
render  search  editor   auth    version
(mdhtml)(mdsearch)(save) (session)(git)
   |
mdparser-0.2 -> AST -> mdhtml-0.1 -> HTML
                    -> mdpdf-0.2  -> PDF (Export)
```

### mdserver als eigenes Modul

`mdserver-oo.tcl` wird zu `mdserver-0.1.tm` paketiert.
Handler-Registrierung via Router:

```tcl
package require mdserver 0.1

mdserver::route GET  {*.md}  mddocs::renderHandler
mdserver::route GET  {/search} mddocs::searchHandler
mdserver::route POST {*.md}  mddocs::saveHandler
mdserver::route GET  {*}     mdserver::staticHandler

mdserver::start --port 8080 --root /docs
```

### TclOO-Klassenstruktur

```
mdserver::Server
   |
   +-- mdserver::Request
   +-- mdserver::Response
   +-- mdserver::Router
   +-- mdserver::Session

mddocs::App (erbt von mdserver::Server)
   |
   +-- mddocs::Renderer   (mdparser + mdhtml)
   +-- mddocs::Search     (mdsearch)
   +-- mddocs::Editor     (POST-Handler + Git)
   +-- mddocs::Auth       (SQLite Sessions)
   +-- mddocs::Version    (Git)
```

---

## Editieren: Lokaler Editor + POST

Statt eines Browser-Editors verwendet mddocs das lokale **mdstack** als Editor.
Artikel werden lokal bearbeitet und als fertiges Ganzes an den Server geschickt.
Kein WebSocket, kein JavaScript, keine JS-Abhaengigkeiten.

### Server: POST-Handler

```tcl
# POST /api/save  body: {path content message}
proc mddocs::saveHandler {req} {
    set path    [dict get $req body path]
    set content [dict get $req body content]
    set msg     [dict get $req body message]
    set user    [dict get $req session user]

    mddocs::save $path $content $user $msg
    return [mdserver::response 200 {saved}]
}

mdserver::route POST /api/save mddocs::saveHandler
```

### mdstack: Publish-Kommando

```tcl
# In mdstack: Artikel an mddocs senden
proc mdstack::publish {path server {msg ""}} {
    set content [readFile $path]
    if {$msg eq ""} { set msg "Update: [file tail $path]" }
    http::post $server/api/save         [list path $path content $content message $msg]
}
```

Aufruf aus mdstack heraus (CLI oder Button):

```bash
tclsh mdstack.tcl publish artikel.md http://localhost:8080
```

### Vorteil gegenueber Browser-Editor

| | Browser-Editor | mdstack + POST |
|---|---|---|
| Komplexitaet Server | hoch (WebSocket) | minimal (~50 Zeilen) |
| Komplexitaet Client | hoch (JS, CodeMirror) | null |
| Live-Preview | WebSocket noetig | mdstack hat eigene Preview |
| Offline-faehig | nein | ja |
| Pure Tcl | nein (JS) | ja |
| Konflikt-Handling | schwierig | Git-Pull vor POST |

---

## Versionierung mit Git

```tcl
# Speichern + Commit
proc mddocs::save {path content user msg} {
    writeFile $path $content
    exec git -C [docRoot] add $path
    exec git -C [docRoot] commit \
        -m "$msg" \
        --author "$user <$user@mddocs>"
}

# History
proc mddocs::history {path} {
    exec git -C [docRoot] log \
        --pretty=format:"%H|%ai|%an|%s" -- $path
}
```

---

## Benutzerverwaltung (SQLite)

```tcl
package require sqlite3

sqlite3 db mddocs.db

db eval {
    CREATE TABLE IF NOT EXISTS users (
        id       INTEGER PRIMARY KEY,
        name     TEXT UNIQUE,
        password TEXT,   -- bcrypt-Hash
        group_id INTEGER
    );
    CREATE TABLE IF NOT EXISTS groups (
        id   INTEGER PRIMARY KEY,
        name TEXT,       -- admin / editor / reader
        can_read   INTEGER DEFAULT 1,
        can_edit   INTEGER DEFAULT 0,
        can_delete INTEGER DEFAULT 0,
        can_admin  INTEGER DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS sessions (
        token    TEXT PRIMARY KEY,
        user_id  INTEGER,
        expires  INTEGER
    );
}
```

---

## Export

```tcl
# Einzelne Seite als PDF
mddocs::exportPdf /docs/api.md api.pdf

# Ganzes Verzeichnis als PDF (zusammengefuehrt)
mddocs::exportBook /docs/ handbuch.pdf
```

---

## Konfiguration (mddocs.conf)

```tcl
# mddocs.conf -- Tcl-Syntax
set cfg(port)     8080
set cfg(tlsport)  8443
set cfg(root)     /home/user/docs
set cfg(theme)    hell
set cfg(title)    "Meine Dokumentation"
set cfg(git)      1          ;# Git-Versionierung
set cfg(auth)     1          ;# Benutzer-Authentifizierung
set cfg(db)       mddocs.db
set cfg(cert)     server.crt
set cfg(key)      server.key
```

---

## Offene Fragen

- **Passwort-Hashing**: `tcllib md5` reicht nicht -- PBKDF2 via `Tcllib sha256` (pure Tcl, entschieden)
- **Concurrent Edits**: Locking-Strategie (File-Lock oder Git-Branch pro User)?
- **Volltextsuche**: `mdsearch` reicht fuer kleine Wikis -- fuer grosse Repos SQLite FTS5
- **Eigenes Repo**: erst als Teil von mdstack, spaeter ggf. extrahieren (entschieden)

---

## Designentscheidungen

### TclOO fuer Struktur

`Request`, `Response`, `Router`, `Session`, `Server` als TclOO-Klassen.
Jede HTTP-Verbindung hat ihren eigenen Zustand -- das ist natuerlich fuer Objekte.

```tcl
set req [mdserver::Request new $chan]
$req method        ;# GET
$req path          ;# /docs/index.md
$req header accept
```

TclOO von Anfang an -- nicht nachtraeglich einbauen.

### Coroutinen fuer Verbindungshandling

Coroutinen erst in Phase 1b einbauen wenn die Grundstruktur steht.
Nicht TclOO und Coroutinen gleichzeitig neu kombinieren.

Relevant fuer:
- Keep-Alive (mehrere Requests pro Verbindung)
- POST /api/save (Datei schreiben)
- Git-Commit via `exec` (blockiert Event-Loop)

### try/trap statt catch -- Pflicht

Kein nacktes `catch` ausser in `finally`. Eigene Fehlercodes fuer alle
Kategorien die der Server kennt.

**Fehlercodes:**

| Code | Bedeutung | HTTP-Status |
|---|---|---|
| `{MDDOCS TRAVERSAL}` | Directory Traversal | 403 |
| `{MDDOCS NOTFOUND}` | Datei nicht gefunden | 404 |
| `{MDDOCS AUTH}` | Nicht authentifiziert | 401 |
| `{MDDOCS FORBIDDEN}` | Keine Berechtigung | 403 |
| `{MDDOCS PARSE}` | Markdown-Fehler | 500 |
| `{POSIX ENOENT}` | Datei-I/O | 404 |

**Muster:**

```tcl
# Fehler ausloesen (in Hilfsproc)
proc safePath {root urlPath} {
    set path [file normalize [file join $root ...]]
    if {![string match "${root}*" $path]} {
        throw {MDDOCS TRAVERSAL} "Directory traversal: $urlPath"
    }
    return $path
}

# Fehler abfangen (im Handler)
try {
    set path [safePath $cfg(root) $urlPath]
    set html [renderMarkdown $path $theme $toc]
    sendResponse $chan "200 OK" text/html $html
} trap {MDDOCS TRAVERSAL} {msg} {
    send403 $chan $msg
} trap {MDDOCS NOTFOUND} {msg} {
    send404 $chan $urlPath
} trap {POSIX ENOENT} {} {
    send404 $chan $urlPath
} on error {msg info} {
    log "Unexpected: $msg"
    send500 $chan $msg
} finally {
    catch {close $chan}
}
```

`catch` ist nur noch in `finally` erlaubt -- fuer das unbedingte Schliessen
des Channels. Ueberall sonst: `try/trap`.

---

## Entwicklungsphasen

### Phase 1: mdserver-0.1.tm

`mdserver-oo.tcl` direkt als Modul paketieren -- kein neues Framework nötig.

**Begründung:** Tcllib enthält bereits `httpd` (TclOO + Coroutinen, Sean Woods),
aber mit schwerem Dependency-Stack: `clay`, `cron`, `websocket`, `mime`,
`fileutil::magic::filetype` u.a. Das ist das Gegenteil von leichtgewichtig.
Ein eigenes `httpserver`-Paket würde mit `httpd` konkurrieren und den
Namespace belasten. `mdserver` ist kein allgemeines Framework -- es ist
der mdstack HTTP-Server, der Name passt.

Schritte:
- `mdserver-oo.tcl` -> `mdserver-0.1.tm` umbenennen
- `package provide mdserver 0.1` ergänzen
- `parseArgs` und Hauptprogramm-Block entfernen (gehören in `mdserver.tcl`)
- In `mdserver.tcl`: `package require mdserver 0.1` + eigener CLI-Block

Aufwand: ~1 Stunde

### Phase 2: mddocs Core

- Rendering (mdparser + mdhtml, bereits vorhanden)
- Suche (mdsearch, bereits vorhanden)
- Static Files
- Konfiguration

Aufwand: ~300 Zeilen

### Phase 3: Auth + User

- SQLite-basierte Benutzerverwaltung
- Session-Cookies
- Gruppen und Rechte
- Passwort-Hashing via PBKDF2 (Tcllib sha256, pure Tcl)

Aufwand: ~300 Zeilen

### Phase 4: Publish-API (mdstack-Integration)

- POST /api/save -- Artikel empfangen + speichern + Git-Commit
- Token-Auth fuer mdstack (kein Browser-Login noetig)
- mdstack publish-Kommando (CLI + Button)

Aufwand: ~50 Zeilen Server + ~50 Zeilen mdstack

### Phase 5: Versionierung

- Git-History anzeigen
- Diff-Ansicht
- Revert

Aufwand: ~200 Zeilen

---

## Abhaengigkeiten

| Paket | Zweck | Verfuegbarkeit |
|-------|-------|---------------|
| mdparser 0.2 | Markdown -> AST | mdstack |
| mdhtml 0.1 | AST -> HTML | mdstack |
| mdtheme 0.1 | CSS-Themes | mdstack |
| mdsearch 0.1 | Volltext | mdstack |
| mdpdf 0.2 | PDF-Export | mdstack |
| sqlite3 | Auth/Suche | Tcl-Standard |
| tls | HTTPS | apt install tcl-tls |
| git | Versionierung | System |

Pure Tcl bis auf tls (C-Extension fuer HTTPS).

---

## Zeitplan (grob)

Vorbedingungen:
- mdstack 0.3.2 (Nested-List-Bug, Tk-Entkopplung)
- pdf4tcl 0.9.4.12 (Core-Erweiterungen)

Dann:
- Phase 1: mdserver-0.1.tm (~1 Stunde)
- Phase 2: mddocs Core (~1 Session)
- Phase 3: Auth (~1 Session)
- Phase 4: Publish-API, mdstack-Integration (~1 Session)
- Phase 5: Git (~1 Session)
