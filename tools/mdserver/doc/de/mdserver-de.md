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

**Speicherort:** `tools/mdserver/mdserver.tcl`, Modul `lib/mdserver-0.4.tm`

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
| `--bind` | (leer) | Adresse, auf der gehorcht wird. Leer heisst **alle Schnittstellen**. Hinter einem Proxy, der die Anmeldung macht, gehoert hier `127.0.0.1` hin — sonst ist der Port von aussen offen und unangemeldet. |
| `--dotfiles` | `0` | Versteckte Dateien und Ordner (`.git`, `.env`, …) ausliefern. Aus, weil eine Wurzel, die zugleich Arbeitskopie ist, sonst `/.git/config` herausgibt. |
| `--trusted-proxy` | (leer) | Gegenstellen, deren `X-Forwarded-For` im Protokoll geglaubt wird. Genaue Uebereinstimmung, keine Netzmasken. Leer heisst: der Kopf wird ignoriert. Mehrere als Liste: `--trusted-proxy "127.0.0.1 10.0.0.5"`. |
| `--maxline` | `8190` | Bytes je Anfrage-/Kopfzeile; darueber **414**. `0` = ohne Grenze. |
| `--maxheader` | `16384` | Bytes aller Koepfe zusammen; darueber **431**. `0` = ohne Grenze. |
| `--healthpath` | `/__mdserver/health` | Pfad des Health-Endpunkts |
| `--root` | `.` | Dokument-Wurzel |
| `--theme` | `hell` | Theme: `hell`, `dunkel`, `solarized` |
| `--style` | `plain` | TOC-Stil: `plain`, `sidebar`, `sticky`, `collapsible` |
| `--stylesdir` | `../styles` | Verzeichnis der CSS-Stile |
| `--navbg` | `#2c3e50` | Navi-Leiste: Hintergrundfarbe |
| `--navfg` | `#ffffff` | Navi-Leiste: Textfarbe |
| `--navmax` | `6` | Navi-Leiste: max. Sektionen inline; mehr klappen ins Dropdown (`0` = nie) |
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
  lib/mdserver-0.4.tm
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

**Sektionen automatisch.** Zusaetzlich haengt die Leiste die **Top-Level-Ordner**
der Wurzel als Links an (Label aus der Sektions-`index.md`-H1, sonst Ordnername)
-- Bereiche wie `Programmiersprachen/` sind so von jeder Seite einen Klick
entfernt, nicht nur ueber *Alle Dokumente*. Ein Ordner erscheint, wenn er
transitiv irgendeine `.md` enthaelt. Abschaltbar mit der Config-Option
`navsections 0`.

**Ueberlauf: das Sektions-Dropdown.** Waechst die Wurzel, waechst sonst auch die
Leiste -- bei acht oder zehn Sektionen mit langen Titeln laeuft sie ueber den
Fensterrand hinaus. Deshalb klappen mehr als `navmax` Sektionen (Standard: 6) in
**ein** Menue mit dem Label aus `navmore` (Standard `&#128193; Bereiche`). Die
Leiste bleibt damit einzeilig, egal wie viele Bereiche die Wurzel hat. Das
Dropdown ist reines CSS (`<details>`/`<summary>`) -- kein JavaScript.

```bash
tclsh mdserver.tcl --root docs --navmax 4      # ab 5 Sektionen: Dropdown
tclsh mdserver.tcl --root docs --navmax 0      # nie einklappen (Verhalten bis 0.2)
```

Zusaetzlich bricht die Leiste bei sehr vielen festen `navlinks` um
(`flex-wrap`), statt zu ueberlaufen; die Links selbst brechen nie mitten im
Titel.

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

## Buecher (Kapitel-Navigation & -Sidebar)

Ein **Buch** ist ein Ordner mit einer `book.tcl` **oder** einer `index.md`, die
einen `<!-- bookkit:toc:begin -->`-Block enthaelt (siehe bookkit). In Buechern
bietet `mdserver` zwei Extras:

**Kapitel-Navigation** (Config `chapternav`, Standard 1). Am Fuss jeder
Kapitelseite eine Leiste **<- voriges | ^ Uebersicht | naechstes ->**. Die
Reihenfolge kommt aus `book.tcl` (`chapters`), sonst aus dem bookkit-TOC-Block
der `index.md`, sonst aus der `NNN-`-Praefix-Ordnung. Die Buch-`index.md` selbst
bekommt keine.

**Kapitel-Sidebar** (nur `?style=sidebar`). In einem Buch zeigt die linke
Sidebar die **komplette Kapitelliste** (aktuelles Kapitel hervorgehoben) statt
des Seiten-TOC. Auf schmalen Schirmen (<= 800px) klappt sie zu einer tippbaren
Leiste **Kapitel** zusammen (reines CSS, kein JavaScript).

Beide Features passen zur Web-Ausgabe von bookkit (`book-webindex.tcl`), das die
`index.md` (Kapitel-TOC) und `stichwortverzeichnis.md` schreibt. Bucherkennung:
`book.tcl` oder ein `bookkit:toc`-Block in der `index.md`.

---

## Health-Endpunkt

```
GET /__mdserver/health   ->  200  ok
                             503  root unreadable
```

Fuer nginx, systemd oder eine Ueberwachung. Er prueft **eine Sache**, statt nur
zu bestaetigen, dass der Prozess lebt: ist die Wurzel noch ein lesbares
Verzeichnis? Ein Endpunkt, der immer 200 sagt, meldet „gesund", wenn `--root`
auf einen nicht mehr eingehaengten Pfad zeigt — nginx schaltet dann auf einen
Server, der fuer alles 404 liefert. Keine Systeminformationen, nur `ok` oder
der Grund. Pfad aenderbar mit `--healthpath`.

---

## Grenzen fuer Anfragen

| | Vorgabe | darueber |
|---|---|---|
| `--maxline` | 8190 Bytes je Zeile | **414 URI Too Long** |
| `--maxheader` | 16384 Bytes alle Koepfe | **431 Request Header Fields Too Large** |

Die Grenze haengt am Lesepuffer, nicht an der fertigen Zeile: eine Zeile ohne
Zeilenende waechst sonst unbegrenzt, und genau das soll die Grenze verhindern.
Nach einer abgewiesenen Anfrage bedient der Server normal weiter. `0` schaltet
eine Grenze ab.

Das Lese-Timeout (15 s, `-timeout`) bleibt davon unberuehrt — es deckt den
langsamen Klienten, die Grenzen den grossen.

---

## Control-Port (sauberes Beenden)

Mit `--control PORT` oeffnet der Server einen **localhost-only** Steuerkanal:

```bash
tclsh mdserver.tcl --root docs --control 8099
```

Kommandos mit dem beiliegenden `mdctl.tcl`:

```bash
tclsh mdctl.tcl --port 8099 stop     # sauber beenden
tclsh mdctl.tcl --port 8099 ping     # -> pong
```

Das ist der empfohlene Weg zum Beenden eines dauerlaufenden Servers -- kein
`fuser -k`, keine PID-Suche.

**Kein `echo stop | nc`.** OpenBSD-netcat, das Standard-`nc` auf Debian und
Ubuntu, schliesst die Senderichtung nach EOF auf stdin nicht und wartet weiter:

```
echo ping | nc    127.0.0.1 8099   ->  leer, laeuft in den Timeout
echo ping | nc -N 127.0.0.1 8099   ->  pong
```

Das `-N` kennen andere netcat-Varianten wieder nicht. Tcl ist da, wo mdserver
laeuft, also braucht es das Raten nicht -- darum `mdctl.tcl`.

### Was beim Beenden passiert

1. Die **Horchsockets** gehen zu: keine neue Verbindung mehr.
2. Laufende Antworten bekommen **5 s**, um fertig zu werden.
3. Danach wird gekappt, mit Protokollzeile:
   `shutdown: 1 Verbindung(en) abgeschnitten`

Bis 0.3.4 fiel Schritt 2 aus -- `shutdown` schloss alle offenen Verbindungen
sofort. Wer gerade eine grosse PDF holte, bekam sie mitten im Byte
abgeschnitten, und zwar bei jedem `systemctl restart`.

### Unter systemd

`mdserver.service.beispiel` liegt neben `mdserver.tcl`. Der Kern:

```ini
ExecStart=/usr/bin/tclsh /opt/mdstack/tools/mdserver/mdserver.tcl \
    --root /srv/md --port 8080 --bind 127.0.0.1 \
    --trusted-proxy 127.0.0.1 --control 8099
ExecStop=/usr/bin/tclsh /opt/mdstack/tools/mdserver/mdctl.tcl --port 8099 stop
TimeoutStopSec=15
```

`TimeoutStopSec` etwas ueber den 5 s, die mdserver sich fuer laufende Antworten
nimmt. Ohne `ExecStop` kommt SIGTERM -- und Tcl hat ohne TclX keine
Signalbehandlung, der Prozess endet dann mitten in der Antwort. Das Protokoll
geht ins Journal und wird nach jeder Zeile geschrieben:

```bash
journalctl -u mdserver -f
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
- **`If-Range`**: ein Bereich gilt nur, wenn die Datei noch dieselbe ist. Passt
  der Validator nicht — oder ist er ein ETag, die mdserver nie ausgibt — kommt
  **200 mit dem ganzen Inhalt** statt 206 (RFC 9110 13.1.5). Bis 0.3.2 wurde
  der Kopf nicht gelesen: ein Viewer konnte Stuecke zweier Fassungen
  zusammenkleben, wenn die Datei waehrend des Lesens neu gespeichert wurde.
- **`If-Modified-Since` / 304 Not Modified**: unveraenderte Dateien werden nicht
  neu gesendet (`Last-Modified` an allen Dateien).

---

## Routing

| URL | Verhalten |
|-----|-----------|
| `/` | `index.md` wenn vorhanden, sonst Verzeichnis-Listing |
| `/datei.md` | Markdown → HTML |
| `/datei` | Clean URL: versucht automatisch `/datei.md` |
| `/verzeichnis` | 301-Redirect auf `/verzeichnis/` (korrekte relative Links) |
| `/verzeichnis/` | `index.md` oder Verzeichnis-Listing |
| `.css`, `.js`, `.png`, `.jpg`, `.gif`, `.svg`, `.pdf` | Statische Datei |
| Nicht gefunden | 404-Seite |
| `POST`, `PUT`, `DELETE`, `OPTIONS`, `PATCH` | **405** mit `Allow: GET, HEAD` |

Ausgeliefert werden nur `GET` und `HEAD`. `HEAD` liefert denselben Kopf wie
`GET` — gleicher Status, gleiches `Content-Length` — aber **keinen Koerper**
(RFC 9110 9.3.2). Das gilt auch fuer 206, 404 und den Verzeichnis-Index. Bis
0.3.1 kam der Koerper mit, obwohl der `Allow`-Kopf HEAD zusagt. Jede andere gueltige HTTP-Methode
bekommt **405** und im Kopf `Allow: GET, HEAD` — der Klient erfaehrt, woran er
ist, statt zu warten. Eine Anfragezeile, die gar kein HTTP ist, bekommt
weiterhin keine Antwort: dafuer gibt es keinen sinnvollen Status, und 405 waere
eine Aussage ueber ein Protokoll, das nie gesprochen wurde.

Jede Antwort traegt `Server: mdserver/<Paketfassung>` — aus
`package provide mdserver`, nicht aus einer zweiten getippten Zahl.

**Clean URLs** erlauben Links ohne `.md`-Endung (z.B. `/dict`, `/array`).
Wird von `nroff2md --linkmode server` für SEE ALSO-Querverweise genutzt.

---

## Verzeichnis-Index

Wenn kein `index.md` vorhanden ist, erscheint ein automatisches
Verzeichnis-Listing mit:

- Unterverzeichnissen
- Markdown-Dateien (Titel aus erstem H1)
- Link zur uebergeordneten Ebene

Das Listing wird ueber **mdstack** gerendert -- gleicher Look und `?style=` wie
alle anderen Seiten (kein separater HTML-Pfad).

---

## Logging

Eine Zeile je Anfrage — Zeit, Adresse, Methode, Pfad, Status, Bytes, dann eine
kurze Notiz. Bis 0.3.4 waren es zwei Zeilen, und Bytes gab es nur bei
statischen Dateien:

```
[09:15:03] 127.0.0.1 GET /index.md 200 6194 markdown
[09:15:03] 127.0.0.1 GET /unter 301 0 -> /unter/
[09:15:03] 192.168.17.42 GET /handbuch.pdf 206 65536 bytes 0-65535/2400000
[09:15:03] 127.0.0.1 GET /style.css 304 0 not modified
[09:15:03] 127.0.0.1 POST /index.md 405 94
```

Die Adresse ist die Gegenstelle — oder der erste `X-Forwarded-For`-Eintrag,
wenn die Gegenstelle in `--trusted-proxy` steht.

Mit `--no-log` deaktivieren.

### Hinter einem Proxy

Als Gegenstelle steht dort immer die Adresse des Proxys — jede Zeile saehe
gleich aus. `X-Forwarded-For` hilft, aber **nur wenn er vom Proxy kommt**:
anhaengen kann den Kopf jeder, der den Port erreicht. Bis 0.3.1 glaubte
mdserver ihn ungeprueft, ein direktes

```bash
curl -H "X-Forwarded-For: 9.9.9.9" http://server:8080/
```

schrieb `9.9.9.9` ins Protokoll. Seit 0.3.2 wird der Kopf nur gelesen, wenn die
**Gegenstelle** in `--trusted-proxy` steht:

```bash
tclsh mdserver.tcl --root /srv/md --bind 127.0.0.1 --trusted-proxy 127.0.0.1
```

Dann nennt das Protokoll den **ersten** Eintrag des Kopfes:

```
[09:15:03] 192.168.17.42 GET /index.md
```

Alles hinter dem ersten Eintrag kann der Klient selbst hineingeschrieben haben
und wird verworfen. Wer dem Loopback traut, traut damit allem, was auf
demselben Rechner laeuft — das ist hinter einem Proxy auf derselben Maschine
richtig so. In nginx:

```nginx
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

Ohne `--trusted-proxy` wird der Kopf gar nicht gelesen. Das Protokoll wird nach
jeder Zeile geschrieben (`flush`) — in eine Datei umgelenkt, also unter
systemd, stand die letzte Anfrage sonst erst Kilobytes spaeter darin.

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

# LAN: Aufruf per Name UND per Adresse
tclsh mkcert.tcl --cn mdstack --san 192.168.1.50 --san mdstack.lan

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
| `--san` | -- | Weiterer Name oder IP im `subjectAltName`. Mehrfach angebbar; der CN steht immer drin. |
| `--no-san` | -- | Ohne `subjectAltName` erzeugen. Browser lehnen das ab. |
| `--check` | -- | Nur Gueltigkeit pruefen |

Erkennt automatisch ob Zertifikat vorhanden und noch gueltig ist.

### subjectAltName (seit 0.3.4)

Aktuelle Browser lesen den **CN nicht mehr als Hostnamen** — Chrome seit 58
(2017) — sondern den `subjectAltName`. Bis 0.3.3 setzte `mkcert.tcl` nur
`-subj /CN=…`, ohne SAN; ein so erzeugtes Zertifikat wird abgelehnt, auch nach
Import in den Zertifikatspeicher (`ERR_CERT_COMMON_NAME_INVALID`).

Der SAN entsteht jetzt aus dem CN: ein Name wird `DNS:`, eine Adresse `IP:`.
Bei `localhost` kommt `IP:127.0.0.1` dazu, weil beide Wege benutzt werden.

```
tclsh mkcert.tcl                        -> DNS:localhost, IP Address:127.0.0.1
tclsh mkcert.tcl --cn mdstack.lan       -> DNS:mdstack.lan
tclsh mkcert.tcl --cn 192.168.1.50      -> IP Address:192.168.1.50
--cn mdstack --san 192.168.1.50 --san mdstack.lan
      -> DNS:mdstack, IP Address:192.168.1.50, DNS:mdstack.lan
```

Wer `https://192.168.1.50/` aufruft, braucht die **Adresse** im SAN, nicht nur
den Namen. Nach dem Erzeugen liest das Skript den SAN aus dem Zertifikat
zurueck und bricht ab, wenn er fehlt.

**Alte Zertifikate:** ein vorhandenes ohne SAN wird beim naechsten Aufruf
ersetzt, auch wenn das Datum noch stimmt — es ist fuer Browser ohnehin
unbrauchbar. `--check` meldet es und endet mit Rueckgabewert 1 statt `OK`:

```
GUELTIG, ABER OHNE subjectAltName: /pfad/server.crt
Browser lehnen es ab (ERR_CERT_COMMON_NAME_INVALID), auch nach Import.
```

`--addext` braucht openssl ab 1.1.1. Fehlt es, bricht `mkcert.tcl` ab statt
still ein Zertifikat ohne SAN zu bauen; `--no-san` erzwingt das alte Verhalten
ausdruecklich.

---

## .gitignore

```
tools/mdserver/server.crt
tools/mdserver/server.key
```

---

## Sicherheitshinweise

- **Directory Traversal** ist blockiert (safePath-Pruefung)
- **Symlinks** fuehren nicht aus der Wurzel heraus. `file normalize` loest den
  letzten Bestandteil eines Pfades **nicht** auf; bis 0.3 wurde ein Verweis
  `docs/hinaus.txt -> /etc/passwd` darum ausgeliefert. Seit 0.3.1 wird jeder
  Bestandteil aufgeloest und das Ergebnis erneut gegen die Wurzel geprueft:
  **403**. Ein Verweis, der innerhalb der Wurzel bleibt, wird normal geliefert.
- **Der Wurzelvergleich geht bis zum Trennzeichen**: `--root /srv/md` passt
  nicht auf `/srv/mdxyz`.
- **Versteckte Dateien** sind aus (`--dotfiles`, siehe Kommandozeile)
- **`X-Forwarded-For`** wird nur von Gegenstellen aus `--trusted-proxy`
  gelesen; Vorgabe leer heisst: gar nicht. Sonst faelscht jeder, der den Port
  erreicht, seine Adresse im Protokoll.
- **`--bind`**: hinter einem Proxy mit Anmeldung gehoert `127.0.0.1` hin, sonst
  ist der Port von aussen offen und unangemeldet
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
    mdserver-0.4.tm   -- Server-Modul
  styles/               -- TOC-CSS-Stile
    sidebar.css
    sticky-top.css
    collapsible.css
  mkcert.tcl            -- Zertifikat-Hilfsskript
  mdctl.tcl             -- Steuerport ansprechen (stop|ping), als ExecStop=
  mdserver.service.beispiel -- systemd-Unit zum Anpassen
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

### 0.4 (2026-09-29)

- **Startmeldung nennt die Bindeadresse** statt immer `localhost`
- **`stop` laesst laufende Antworten zu Ende** (5 s), statt sie zu kappen
- **Health-Endpunkt** `/__mdserver/health`, prueft die Wurzel
- **Eine Protokollzeile je Anfrage**, mit Adresse, Status und Bytes
- **`--maxline` / `--maxheader`** -> 414 / 431
- **`mdctl.tcl`** und `mdserver.service.beispiel` fuer den Betrieb unter systemd

### 0.3.4 (2026-09-29)

- **`mkcert.tcl` setzt `subjectAltName`** aus dem CN, `--san` haengt weitere an.
  Ohne SAN lehnen aktuelle Browser das Zertifikat ab. Ein vorhandenes ohne SAN
  wird ersetzt, `--check` meldet es statt `OK`. `--no-san` fuer den alten Weg

### 0.3.3 (2026-09-29)

- **`If-Range`** wird ausgewertet: passt der Validator nicht, kommt 200 mit dem
  ganzen Inhalt statt 206 aus der neuen Fassung

### 0.3.2 (2026-09-28)

- **HEAD ohne Koerper** (RFC 9110 9.3.2) — auf allen Wegen, auch 206 und 404.
  Bis 0.3.1 kam der Koerper mit, obwohl `Allow: GET, HEAD` ihn zusagt
- **`--trusted-proxy ADDR ...`**: `X-Forwarded-For` wird nur von diesen
  Gegenstellen gelesen, Vorgabe leer

### 0.3.1 (2026-09-28)

- **`--bind ADDR`**: an welche Adresse HTTP und HTTPS gehen. Leer bleibt die
  Vorgabe (alle Schnittstellen). Eine Adresse, die es nicht gibt, bricht den
  Start ab und nennt sie — kein stiller Rueckfall
- **Symlinks fuehren nicht mehr aus der Wurzel heraus** (403), der
  Wurzelvergleich geht bis zum Trennzeichen
- **`--dotfiles 0|1`**, Vorgabe aus
- **405 mit `Allow: GET, HEAD`** statt Schweigen bei fremden Methoden
- **`X-Forwarded-For`** (erster Eintrag) im Protokoll; `flush` nach jeder Zeile
- **`Server:`-Kopf** aus `package provide mdserver`

### 0.3

- **Navi-Leiste laeuft nicht mehr ueber**: mehr als `navmax` Sektionen
  (Standard 6) klappen in ein reines CSS-Dropdown (`navmore`); die Leiste
  bricht um statt ueberzulaufen, Links brechen nie mitten im Titel
- **`--theme` wirkt wieder**: das Theme-CSS (`mdstack::theme::toCSS`) wird von
  mdserver selbst eingebettet. docir::html kennt nur sein eigenes Default-CSS --
  `hell`, `dunkel` und `solarized` lieferten zuvor identische Seiten
- Kaskade: Default-CSS -> Theme-CSS -> Style-Datei (`--style`)

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
