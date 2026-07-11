# mdserver

> Version 0.2 (module) -- concurrent (coroutine), slow-loris resistant,
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

**Location:** `tools/mdserver/mdserver.tcl`, module `lib/mdserver-0.2.tm`

---

## Dependencies

| Package | Version | Required |
|---------|---------|----------|
| `Tcl` | 8.6 or 9 | yes |
| `mdstack::parser` | 0.2 | yes |
| `mdstack::html` | 0.1 | yes |
| `mdstack::theme` | 0.1 | recommended |
| `tls` | — | HTTPS only |

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
| `--root` | `.` | Document root |
| `--theme` | `hell` | Theme: `hell`, `dunkel`, `solarized` |
| `--style` | `plain` | TOC style: `plain`, `sidebar`, `sticky`, `collapsible` |
| `--stylesdir` | `../styles` | Directory holding the CSS styles |
| `--navbg` | `#2c3e50` | Nav bar background color |
| `--navfg` | `#ffffff` | Nav bar text color |
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
| `plain` | default block at the top |
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
reached via the **Alle Dokumente** link.

**Sections automatically.** The bar also appends the **top-level folders** of
the root as links (label from the section's `index.md` H1, else the folder
name) -- areas like `Programmiersprachen/` are one click away from every page,
not only via *Alle Dokumente*. A folder appears if it transitively contains any
`.md`. Disable with the `navsections 0` option.

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

**Clean URLs** allow links without `.md` extension (e.g. `/dict`, `/array`).
Used by `nroff2md --linkmode server` for SEE ALSO cross-references.

---

## Troubleshooting

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

- Directory traversal blocked (safePath check)
- Control port binds to `127.0.0.1` only
- Self-signed certificates trigger browser warnings (dev only)
- No authentication built in -- restrict at network level for sensitive docs
- Suitable for preview and LAN; put a reverse proxy in front for public use

---

## File structure

```
tools/mdserver/
  mdserver.tcl        -- CLI launcher
  lib/mdserver-0.2.tm -- server module
  styles/             -- TOC CSS styles (sidebar/sticky-top/collapsible)
  mkcert.tcl          -- certificate helper
  test/               -- test suite
  mdserver-demo/      -- demo site
```

---

## Changelog

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
