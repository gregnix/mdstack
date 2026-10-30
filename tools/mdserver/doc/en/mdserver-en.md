# mdserver

> Version 0.4 (module) -- concurrent (coroutine), slow-loris resistant,
> Range / Conditional-GET, control port, TOC styles.

## Purpose

`mdserver` is an HTTP/HTTPS web server in pure Tcl (no Tk).
It serves Markdown files as HTML on the fly.

- No Tk, no display, no fonts needed
- **Concurrent**: one coroutine per connection, non-blocking I/O
  (multiple users at once; a slow client does not block others)
- HTTP always active, HTTPS optional with TLS certificate
- Theme and **TOC style** selection via URL parameter
- **Navigation**: home page, site-wide document index, fixed nav bar
- **Range requests (206)** -- large PDFs/images seekable in the browser
- **Conditional GET (304)** -- unchanged files are not resent
- **Control port** -- clean shutdown without `fuser -k`
- Static files served directly
- Directory index with automatic file listing

**Location:** `tools/mdserver/mdserver.tcl`, module `lib/mdserver-0.4.tm`

---

## Dependencies

| Package | Version | Required |
|---------|---------|----------|
| `Tcl` | 8.6 or 9 | yes |
| `mdstack::parser` | 0.2 | yes |
| `mdstack::html` | 0.1 | yes |
| `docir`, `docir::mdSource`, `docir::html`, `docir::diag`, `docir::diagram` | 0.1 | yes (needed by `mdstack::html` 0.2) |
| `mdstack::theme` | 0.1 | recommended |
| `tls` | — | HTTPS only |
| tclutils: `tupdftext`, `tutask` | 0.1, 0.2 | no; PDFs in the search |
| tclutils: `tuodf`, `tudocx`, `tuxlsx` | 0.1 (ODF headings from `tuodf` 0.2) | no; office files in the search |
| tclutils: `tucsv` | 0.2 | no; CSV as a table page |
| tclutils: `tujson` | 0.1 | no; search as JSON (`format=json`) |
| tclutils: `common` | 0.3 | no; PDF cache through `replaceFile` (else the same by hand) |

tclutils stays optional: mdserver looks for it on the module path or in
`TCLUTILS_TM` and without it leaves out only these parts.

```bash
# Install tls (Debian/Ubuntu)
apt install tcl-tls
```

Runs unchanged on Tcl/Tk **8.6 and 9.0**.

---

## Command line

```bash
tclsh mdserver.tcl [options]
```

| Option | Default | Description |
|--------|---------|-------------|
| `--port` | `8080` | HTTP port |
| `--bind` | (empty) | Listen address. Empty means **all interfaces**. Behind a proxy that does the authentication this must be `127.0.0.1` -- otherwise the port is reachable from outside and unauthenticated. |
| `--dotfiles` | `0` | Serve hidden files and directories (`.git`, `.env`, …). Off by default: a document root that is also a working copy would otherwise hand out `/.git/config`. |
| `--pdf-search` | `auto` | PDFs in the full-text search, one hit per page. Needs `tclutils::tupdftext` (tclutils 0.67.0) on the module path or in `TCLUTILS_TM`. `auto`: when it loads; `1`: otherwise a warning; `0`: off. |
| `--pdf-cache` | `~/.cache/mdserver-pdf` | Folder for the PDF text read, one file per PDF, valid while mtime and size match. Never inside the root. |
| `--pdf-worker` | `1` | Read PDFs in a second `tclsh`, so a search does not hold up other requests. `0`: in the server process. |
| `--office-search` | `auto` | `.odt`, `.ods`, `.odp`, `.docx` and `.xlsx` in the full-text search, one hit per file. Needs `tclutils::tuodf`, `tudocx` or `tuxlsx`; each format whose module loads. `auto`, `1`, `0` as for `--pdf-search`. |
| `--csv-view` | `auto` | `.csv` as a table page in style `site` and in the search; `?raw=1` sends the file itself. Needs `tclutils::tucsv` 0.2. `auto`, `1`, `0` as above. |
| `--trusted-proxy` | (empty) | Peer addresses whose `X-Forwarded-For` is believed in the log. Exact match, no netmasks. Empty means the header is ignored. Several as a list: `--trusted-proxy "127.0.0.1 10.0.0.5"`. |
| `--maxline` | `8190` | Bytes per request/header line; over that **414**. `0` = no limit. |
| `--maxheader` | `16384` | Bytes of all headers; over that **431**. `0` = no limit. |
| `--healthpath` | `/__mdserver/health` | Path of the health endpoint |
| `--root` | `.` | Document root |
| `--theme` | `hell` | Theme: `hell`, `dunkel`, `solarized` |
| `--style` | `site` | page style: `site`, `plain`, `sidebar`, `sticky`, `collapsible` |
| `--stylesdir` | `../styles` | Directory holding the CSS styles |
| `--navbg` | `#2c3e50` | Nav bar background color |
| `--navfg` | `#ffffff` | Nav bar text color |
| `--navmax` | `6` | Nav bar: max. sections shown inline; more fold into a dropdown (`0` = never) |
| `--title` | `mdserver` | Site title |
| `--toc` | `1` | Table of contents (0\|1) |
| `--control` | `""` | Control port (localhost only; `stop`/`ping`) |
| `--no-log` | — | Disable logging |
| `--cert` | `""` | TLS certificate (.crt/.pem) |
| `--key` | `""` | TLS private key (.key) |
| `--tlsport` | `8443` | HTTPS port |
| `--help` | — | Show help |

---

## HTTP usage

```bash
tclsh mdserver.tcl --root /path/to/docs
tclsh mdserver.tcl --port 9000 --theme dunkel
tclsh mdserver.tcl --root docs --style sidebar --control 8099
```

---

## Concurrency (LAN use)

Since 0.2 each connection is served in its own **coroutine** with non-blocking
reads/writes. Multiple clients are served at once; a client that connects and
sends nothing (slow-loris) does not freeze the server (a read timeout discards
it); large files do not block other connections. Suitable for serving manuals
on a company LAN. For public servers put a reverse proxy in front.

---

## TOC styles (`?style=`)

The table of contents (`<nav class="toc">`) can be displayed differently via CSS
styles -- the same styles as mdhelp's HTML export:

| Style | Effect |
|-------|--------|
| `site` | complete page layout: header, sidebar (book chapters or the folder), breadcrumbs, "on this page" column, folder pages as cards, light/dark -- default |
| `plain` | TOC block at the top (the default up to 0.4) |
| `sidebar` | fixed left sidebar, stays visible while scrolling |
| `sticky` | TOC sticks to the top edge |
| `collapsible` | collapsible TOC |

Per request: `http://localhost:8080/doc.md?style=sidebar`
As default: `tclsh mdserver.tcl --root docs --style sidebar`

**CSS location:** the styles live in `styles/` next to `lib/`
(`tools/mdserver/styles/`). Override with `--stylesdir`. The server injects the
chosen style as an extra `<style>` block after the default CSS (cascade wins);
if the file is missing it serves unstyled (no error).

---

## Navigation

A slim **nav bar** is injected at the top of every page, plus a **site-wide
index** of all documents.

**Home** is the root `index.md`; the **Start** link always returns there (`/`).

**Site index** via the route **`?nav=index`**: recursively lists every `.md`
under the root as a tree (titles from the first `# H1`, directories bold),
reached via the **Alle Dokumente** link. PDFs are listed too, by file name and marked "(PDF)"; a folder that holds only PDFs counts as a folder of documents (up to 2026-10-20 it was hidden from the bar, the sidebar and the tiles). Folder tiles show a PDF as a document with "PDF" and its size; the folder sidebar lists PDFs after the Markdown documents. The start banner has a line `PDF:` saying whether the PDF search is on, and if not, why.

**Sections automatically.** The bar also appends the **top-level folders** of
the root as links (label from the section's `index.md` H1, else the folder
name) -- areas like `Programmiersprachen/` are one click away from every page,
not only via *Alle Dokumente*. A folder appears if it transitively contains any
`.md`. Disable with the `navsections 0` option.

**Overflow: the section dropdown.** As the root grows, so would the bar -- with
eight or ten sections and long titles it runs past the window edge. So more than
`navmax` sections (default 6) fold into **one** menu, labelled by `navmore`
(default `&#128193; Bereiche`). The bar stays a single line however many areas
the root has. The dropdown is pure CSS (`<details>`/`<summary>`) -- no JavaScript.

```bash
tclsh mdserver.tcl --root docs --navmax 4      # 5 sections or more: dropdown
tclsh mdserver.tcl --root docs --navmax 0      # never fold (0.2 behaviour)
```

The bar also wraps (`flex-wrap`) instead of overflowing when there are many
fixed `navlinks`; the links themselves never break mid-title.

Customise colours via CLI, links/icons via the constructor:

```bash
tclsh mdserver.tcl --root docs --navbg "#800000" --navfg "#ffdd00"
```

```tcl
mdserver::Server new -root docs -navlinks {
    {{&#127968; Start} /}
    {{&#128218; Alle Dokumente} /?nav=index}
}
```

Disable with the `nav 0` option (constructor). In the sidebar style the bar is a
fixed top bar.

---

## Style `site`

`--style site` (or `?style=site`) does not lay a stylesheet over the rendered
page; it takes the rendered body and builds the page around it, with one
stylesheet (`styles/site.css`): a header with the sections, a left sidebar
(the book's chapters with PDF/HTML downloads, or the current folder), the text
column with breadcrumbs, and an "on this page" column for pages with at least
three h2/h3 headings. Folders without `index.md` are shown as cards: books
first (title and subtitle from `book.tcl`), then folders, documents (with their
first paragraph) and other files. In books, previous/next are two cards. Narrow
screens get a menu button for the sidebar (CSS only, no JavaScript). Dark mode
follows the system setting, or `?theme=dunkel`. A missing page is a 404 page
with a way back.

**Search.** The header carries a search field; `/?q=words` lists the
documents that contain all words (case-insensitive, `ae`/`oe`/`ue`/`ss` match
the umlauts), best first (title hits weigh more), each with its folder path and
a snippet with the words marked. The texts are read once and kept with their
mtime; a search rereads only changed files. Dot folders and symlinks are left
out, as for serving. The other styles answer `?q=` with a plain list.

**Search syntax.** Besides plain words `?q=` understands:

| Input | Effect |
|---|---|
| `"die Freigabe"` | phrase: the words in this order |
| `-proxy` / `-"im Archiv"` | documents with this word or phrase are left out |
| `a OR b`, `a ODER b`, `a \| b` | either of the two; binds the two neighbours only. Upper case only, `or` is an ordinary word |
| `in:folder/sub` | only below this folder (relative to the root) |
| `typ:md`, `typ:pdf`, `typ:office`, `typ:csv` | only Markdown files, PDF pages, office or CSV files (`typ:office` also as `odf`, `docx`, `xlsx`) |

`in` and `typ` also work as URL parameters (`?q=...&in=book&typ=pdf`); what
the query says wins over the parameter. `..`, `.` and dot folders in `in`
count as "everywhere". The result page offers *Bereich* (scope) and *Typ*
below the search field. The search field in the header sends the folder of
the current page along as `von=`; *Bereich* then offers this folder and all
above it, with their titles. The search itself still covers everything until
a scope is chosen.

**PDFs in the search.** When `tclutils::tupdftext` loads (`--pdf-search
auto`, the default), `?q=` also searches every `.pdf` below the root, page by
page. A hit reads `handbook, S. 17` and links to `handbook.pdf#page=17`;
pdf.js (Firefox) and Chrome open that page. `tupdftext` reads the text in pure
Tcl, about 30 ms per page; it goes into `--pdf-cache` and is read again only
for a new or changed PDF (mtime, size). The reading runs in a `tclsh` per PDF
(`lib/pdftext-worker.tcl`, `--pdf-worker 1`, the default), started and awaited
through `tclutils::tutask` (`await [pipe ...] -timeout`), one PDF after the
other, right after the start and then for every new or changed PDF. mdserver does not wait for it: a search returns what is in the
cache and says "3 PDFs werden noch gelesen"; pages and other requests are
answered at once. Up to 2026-10-20 mdserver read in its own process and every
request waited (measured: 16 PDFs, 1804 pages, empty cache: 36 s for the
search and 36 s for a page asked for at the same time; with the worker 0.03
and 0.04 s). `--pdf-worker 0` reads in the server process again; so does a server
without `tutask` or `pdftext-worker.tcl`, or one running as a starpack. If the
worker fails on a PDF (crash, exit code, more than 10 minutes), the next search
tries again; if it fails a second time, the PDF stays out until it changes. A PDF without text (scan, encrypted) gives no
hit.

Server and worker write the PDF cache through a temporary file
(`tclutils::common::replaceFile`, else the same by hand): if writing fails,
the old entry stays and no channel is left open. Up to 2026-10-29 an error in
`puts` left the channel open.

**Office files in the search.** With `--office-search auto`, `?q=` also
searches office files, each format whose module from tclutils loads:
`.odt`, `.ods`, `.odp` with `tuodf`, `.docx` with `tudocx`, `.xlsx` with
`tuxlsx` (the latter two from tclutils 0.69.0). One hit per file, linked to
the file itself. It reads the text of the paragraphs, also in tables, lists
and on slides, and for spreadsheets the content of all cells of all sheets;
ODF headings only with `tuodf` 0.2. Reading is quick (a zip and a few XML
parts) and runs in the server process; the text stays in the search index
with its mtime. `typ:office` narrows to these files. The start banner names
the searched formats in the line `Office:`.

**CSV as a table page.** When `tclutils::tucsv` 0.2 loads (`--csv-view
auto`), style `site` shows a `.csv` as a table: first row as the header, at
most 2000 rows, above it a link "als CSV herunterladen" to `file.csv?raw=1`.
The delimiter is `;` when the first line has more of them than `,`, else `,`.
The file is read as UTF-8 when the bytes are valid UTF-8, else as cp1252
(Excel on Windows). The content is in the search as well (`typ:csv`). The
other styles send the file unchanged.

**Search as JSON.** `?q=...&format=json` (in every style) returns the hits as
JSON, with `in` and `typ` as above:

```json
{"query":"proxy_pass","pending":0,"hits":[{"url":"/a/eins.md",
 "title":"Netzwerk","path":"A","snippet":"... der proxy_pass Wert.","score":1}]}
```

`snippet` is plain text without `<mark>`; `pending` counts the PDFs the
worker is still reading. Needs `tclutils::tujson`; without it mdserver
answers **501**.

**Book landing page.** A book folder (with `book.tcl`) without `index.md` gets
a generated one, in every style: title, subtitle, the first paragraph of the
README, PDF/HTML downloads (bookkit's `<name>.pdf` / `.html` next to the book
folder) and the chapter list. Before, the "Overview" link of the chapter bar
ended in 404. `book-webindex.tcl` still writes a real `index.md` if wanted.

---

## Books (chapter navigation & sidebar)

A **book** is a folder with a `book.tcl` **or** an `index.md` that carries a
`<!-- bookkit:toc:begin -->` block (see bookkit). In books `mdserver` adds two
extras:

**Chapter navigation** (`chapternav` option, default 1). At the foot of each
chapter page a bar **<- previous | ^ Overview | next ->**. The order comes from
`book.tcl` (`chapters`), else the bookkit TOC block in `index.md`, else the
`NNN-` prefix order. The book's own `index.md` gets none.

**Chapter sidebar** (`?style=sidebar` only). In a book the left sidebar shows the
**full chapter list** (current chapter highlighted) instead of the per-page TOC.
On narrow screens (<= 800px) it collapses into a tappable **Kapitel** bar (pure
CSS, no JavaScript).

Both features pair with bookkit's web output (`book-webindex.tcl`), which writes
`index.md` (chapter TOC) and `stichwortverzeichnis.md`. Book detection:
`book.tcl` or a `bookkit:toc` block in `index.md`.

---

## Control port

`--control PORT` opens a localhost-only control channel:

```bash
echo stop | nc localhost 8099    # clean shutdown
echo ping | nc localhost 8099    # -> pong
```

Recommended way to stop a long-running server (no `fuser -k`, no PID lookup).

---

## HTTPS usage

```bash
# 1. Generate certificate
tclsh mkcert.tcl --cn myserver.local --days 730
# LAN, reached by name AND by address:
tclsh mkcert.tcl --cn mdstack --san 192.168.1.50 --san mdstack.lan

# 2. Start (HTTP 8080 + HTTPS 8443)
tclsh mdserver.tcl --root /path/to/docs --cert server.crt --key server.key
```

Without `--cert`/`--key` only HTTP runs (no error). The TLS handshake is driven
through the non-blocking coroutine. Test a self-signed cert with
`curl -k https://localhost:8443/`.

TLS 1.2 / 1.3 active; SSL2/3 and TLS 1.0/1.1 disabled.

---

## URL parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `?theme=` | `hell`, `dunkel`, `solarized` | Override theme per request |
| `?toc=` | `0`, `1` | Override TOC per request |
| `?style=` | `plain`, `sidebar`, `sticky`, `collapsible` | Override TOC style per request |

---

## File serving

- **`Range` / 206 Partial Content**: `bytes=0-99`, `bytes=1000-`, `bytes=-50`;
  invalid -> `416`. With `Accept-Ranges: bytes` and `Content-Range`.
- **`If-Modified-Since` / 304 Not Modified**: `Last-Modified` on all files.

---

## Routing

| URL pattern | Result |
|-------------|--------|
| `/file.md` | Rendered as HTML |
| `/file` | Clean URL: tries `/file.md` automatically |
| `/file.html` | Served as-is |
| `/image.png` | Served with correct MIME type |
| `/dir` | 301 redirect to `/dir/` (correct relative links) |
| `/dir/` | Directory index or `index.md` |
| `/` | Directory index or `index.md` |
| `POST`, `PUT`, `DELETE`, `OPTIONS`, `PATCH` | **405** with `Allow: GET, HEAD` |

Only `GET` and `HEAD` are served. `HEAD` returns the same headers as `GET` --
same status, same `Content-Length` -- but **no body** (RFC 9110 9.3.2), and
that holds for 206, 404 and the directory index too. Up to 0.3.1 the body came
along, although the `Allow` header promises HEAD. Any other valid HTTP method gets **405** with
an `Allow: GET, HEAD` header, so the client is told rather than left waiting. A
request line that is not HTTP at all gets no answer -- there is no meaningful
status for it, and 405 would be a claim about a protocol that was never spoken.

Every response carries `Server: mdserver/<package version>`, taken from
`package provide mdserver` rather than typed a second time.

**Clean URLs** allow links without `.md` extension (e.g. `/dict`, `/array`).
Used by `nroff2md --linkmode server` for SEE ALSO cross-references.

---

## Troubleshooting

### File names with umlauts: 404

The start banner shows `Achtung: Systemkodierung iso8859-1`. Without `LANG`
(the rule under systemd) Tcl does not read file names as UTF-8. Set
`LANG=C.UTF-8`, under systemd `Environment=LANG=C.UTF-8` (in
`mdserver.service.beispiel`).

### Port already in use

Prefer the control port for a clean stop. Otherwise:

```bash
fuser -k 8080/tcp
lsof -ti:8080 | xargs kill
```

### `?style=sidebar` has no effect

Server cannot find the CSS styles. Ensure `tools/mdserver/styles/` exists (or set
`--stylesdir`).

### HTTPS `unexpected eof` / `self-signed certificate`

- `unexpected eof`: HTTP port addressed with `https://` -- check scheme/port.
- `self-signed certificate (18)`: handshake fine, curl distrusts the cert -> `curl -k`.

---

## Security notes

- **URL path and query are never evaluated**: `%XX` is decoded byte by
  byte, `+` becomes a space only in the query. A `%` without two hex
  digits, `%00` or NUL in the path gives **400**; in the query such a `%`
  stays text (`?q=50%`). Up to the state of
  2026-10-30 the path went through `subst`, so `/[exec ...]` ran commands
  as the server user. Update every older installation.
- Directory traversal blocked (safePath check)
- **Symlinks do not lead out of the root.** `file normalize` does not resolve
  the final component of a path, so up to 0.3 a link `docs/out.txt ->
  /etc/passwd` was served. Since 0.3.1 every component is resolved and the
  result checked against the root again: **403**. A link that stays inside the
  root is served normally.
- **The root comparison goes up to the separator**: `--root /srv/md` does not
  match `/srv/mdxyz`.
- Hidden files are off by default (`--dotfiles`)
- `--bind 127.0.0.1` behind a proxy that authenticates -- otherwise the port is
  reachable from outside and unauthenticated
- Behind a proxy the peer is always the proxy's address. `X-Forwarded-For` is
  read **only** from peers listed in `--trusted-proxy` (empty by default =
  never), and only its **first** entry -- anyone reaching the port can append
  to that header, so up to 0.3.1 a plain
  `curl -H "X-Forwarded-For: 9.9.9.9"` wrote `9.9.9.9` into the log
- Control port binds to `127.0.0.1` only
- Self-signed certificates trigger browser warnings (dev only)
- No authentication built in -- restrict at network level for sensitive docs
- Suitable for preview and LAN; put a reverse proxy in front for public use

---

## File structure

```
tools/mdserver/
  mdserver.tcl        -- CLI launcher
  lib/mdserver-0.4.tm -- server module
  lib/pdftext-worker.tcl -- reads one PDF for the search (--pdf-worker)
  styles/             -- TOC CSS styles (sidebar/sticky-top/collapsible)
  mkcert.tcl          -- certificate helper
  mdctl.tcl           -- control port client (stop|ping), systemd ExecStop=
  mdserver.service.beispiel -- sample systemd unit
  test/               -- test suite
  demo/               -- demo site (start.tcl, docs/)
```

---

## Changelog

**Unreleased (2026-10-30), security** -- the URL path went through `subst`
(command execution via `/[exec ...]`); now plain `%XX` decoding, invalid
UTF-8 stays as bytes; a broken `%`, `%00` or NUL in the path gives 400. Under Tcl 9 a file with invalid UTF-8 no longer gives
500; `.xml` as `application/xml`; tab-separated CSV; the start banner warns
when the system encoding is not UTF-8.

**Unreleased (2026-10-30)** -- search syntax: `"phrase"`, `-word`, `a OR b`
(also `ODER`, `|`), `in:folder`, `typ:md|pdf`; `in` and `typ` also as URL
parameters. The result page offers *Bereich* (the folder of the page the
search came from and those above it) and *Typ*. office files in the search
(`--office-search`; `.odt`/`.ods`/`.odp`, `.docx`, `.xlsx` through
`tclutils::tuodf`, `tudocx`, `tuxlsx`); CSV as a table page (`--csv-view`,
`tclutils::tucsv`, `?raw=1`); search as JSON (`?format=json`,
`tclutils::tujson`); the PDF cache is written through a temporary file.

**Unreleased (2026-10-21)** -- PDFs in the full-text search (`--pdf-search
auto|0|1`, `--pdf-cache DIR`): one hit per page, linked as
`file.pdf#page=N`, text through `tclutils::tupdftext`, cached outside the root. PDF worker (`--pdf-worker 0|1`): PDFs are read in a tclsh per PDF through tclutils::tutask, a search no longer blocks the server. PDFs in the navigation: PDF-only folders appear,
PDFs as document tiles, in the sidebar and in the site index; banner line `PDF:`.

**0.4 (2026-09-29)** -- the start banner names the address actually bound
(`0.0.0.0:8080 (alle Schnittstellen)` vs `127.0.0.1:8080`) instead of always
saying `localhost`. `stop` now closes only the listeners and gives running
responses 5 s before cutting them, so a `systemctl restart` no longer truncates
a PDF mid-byte. Health endpoint `/__mdserver/health` (`--healthpath`) that
checks one thing — is the root still a readable directory — with `200 ok` or
`503 root unreadable`. One log line per request with client IP, status and
bytes (bytes now for Markdown too). `--maxline` / `--maxheader` answer 414 /
431. `mdctl.tcl` talks to the control port and works as systemd `ExecStop=`;
`mdserver.service.beispiel` is a sample unit.

**0.3.4 (2026-09-29)** -- `mkcert.tcl` sets `subjectAltName` from the CN
(`DNS:` for a name, `IP:` for an address; `localhost` also gets
`IP:127.0.0.1`), and `--san` appends more. Current browsers do not read the CN
as a hostname, so a certificate without SAN is rejected even after being
imported. An existing SAN-less certificate is replaced on the next run, and
`--check` reports it instead of saying `OK`. `--no-san` keeps the old
behaviour on purpose.

**0.3.3 (2026-09-29)** -- `If-Range` is honoured: when the validator does
not match (or is an ETag, which mdserver never issues), the whole file is sent
with 200 instead of a 206 slice of the new revision (RFC 9110 13.1.5).

**0.3.2 (2026-09-28)** -- HEAD returns headers without a body (RFC 9110 9.3.2),
on every path including 206 and 404. `--trusted-proxy ADDR ...`:
`X-Forwarded-For` is read only from those peers, empty by default.

**0.3.1 (2026-09-28)** -- `--bind ADDR` for HTTP and HTTPS (empty = all
interfaces; a non-existent address aborts the start and names it). Symlinks no
longer lead out of the document root (403), and the root comparison goes up to
the separator. `--dotfiles 0|1`, off by default. 405 with `Allow: GET, HEAD`
instead of silence for other methods. `X-Forwarded-For` (first entry) in the
log, flushed per line. `Server:` header from `package provide mdserver`.

**0.3** -- nav bar overflow: more than `navmax` sections (default 6) fold into a
CSS-only dropdown (`navmore` label), bar wraps instead of overflowing. `--theme`
works again: the theme CSS (`mdstack::theme::toCSS`) is embedded by mdserver
itself -- docir::html knows only its own default CSS, so hell / dunkel /
solarized used to render identically.

**0.2 (2026-07-11)** -- nav bar auto-sections (`navsections`), trailing-slash
redirect for directories, directory listing rendered via mdstack, chapter
navigation in books (`chapternav`), book chapter sidebar (`?style=sidebar`,
collapsible on mobile), Content-Length counted in UTF-8 bytes.

**0.2 (2026-07-09)** -- coroutine/non-blocking concurrency, slow-loris timeout,
Range (206), Conditional GET (304), control port (`--control`), TOC styles
(`--style` / `?style=`), navigation bar + site index (`?nav=index`,
`navbg`/`navfg`/`navlinks`), non-blocking TLS handshake, Tcl 9.

**0.1** -- HTTP/HTTPS, Markdown->HTML, directory index, `?theme=`/`?toc=`,
static files, `mkcert.tcl`, `start.tcl`.
