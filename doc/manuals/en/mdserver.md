# mdserver

> Version 0.2

## Purpose

`mdserver` is an HTTP/HTTPS web server in pure Tcl (no Tk).
It serves Markdown files as HTML on the fly.

- No Tk, no display, no fonts needed
- HTTP always active, HTTPS optional with TLS certificate
- Theme selection via URL parameter
- Static files served directly
- Directory index with automatic file listing

**Location:** `tools/mdserver/mdserver.tcl`

---

## Dependencies

| Package | Version | Required |
|---------|---------|----------|
| `mdstack::parser` | 0.2 | yes |
| `mdstack::html` | 0.1 | yes |
| `mdstack::theme` | 0.1 | recommended |
| `tls` | — | HTTPS only |

```bash
# Install tls (Debian/Ubuntu)
apt install tcl-tls
```

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
| `--trusted-proxy` | (empty) | Peer addresses whose `X-Forwarded-For` is believed in the log. Exact match, no netmasks. Empty = header ignored. |
| `--maxline` | `8190` | Bytes per request/header line; over that 414 |
| `--maxheader` | `16384` | Bytes of all headers; over that 431 |
| `--healthpath` | `/__mdserver/health` | Health endpoint path |
| `--root` | `.` | Document root |
| `--theme` | `hell` | Theme: `hell`, `dunkel`, `solarized` |
| `--title` | `mdserver` | Site title |
| `--toc` | `1` | Table of contents (0\|1) |
| `--no-log` | — | Disable logging |
| `--cert` | `""` | TLS certificate (.crt/.pem) |
| `--key` | `""` | TLS private key (.key) |
| `--tlsport` | `8443` | HTTPS port |
| `--help` | — | Show help |

---

## HTTP usage

```bash
# Current directory
tclsh mdserver.tcl

# Specific directory
tclsh mdserver.tcl --root /path/to/docs

# Custom port and theme
tclsh mdserver.tcl --port 9000 --theme dunkel
```

---

## HTTPS usage

```bash
# 1. Generate certificate with mkcert.tcl
tclsh mkcert.tcl
tclsh mkcert.tcl --cn myserver.local --days 730
# reached by name and by address:
tclsh mkcert.tcl --cn mdstack --san 192.168.1.50 --san mdstack.lan

# 2. Start server (HTTP on 8080 + HTTPS on 8443)
tclsh mdserver.tcl \
    --root /path/to/docs \
    --cert server.crt \
    --key  server.key
```

Or with openssl:

```bash
openssl req -x509 -newkey rsa:4096 \
    -keyout server.key -out server.crt \
    -days 365 -nodes -subj "/CN=localhost"
```

---

## URL parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `?theme=` | `hell`, `dunkel`, `solarized` | Override theme per request |
| `?toc=` | `0`, `1` | Override TOC per request |

---

## Routing

| URL pattern | Result |
|-------------|--------|
| `/file.md` | Rendered as HTML |
| `/file.html` | Served as-is |
| `/image.png` | Served with correct MIME type |
| `/` | Directory index or `index.md` |

Only `GET` and `HEAD` are served. `HEAD` returns the headers `GET` would send,
including the same `Content-Length`, but no body (RFC 9110 9.3.2). Any other valid HTTP method gets **405**
with an `Allow: GET, HEAD` header, so a client is told rather than left
waiting. A request line that is not HTTP at all gets no answer — there is no
meaningful status for it, and 405 would be a claim about a protocol that was
never spoken.

`If-Range` is honoured on static files: a range is served only when the
validator still matches the file, otherwise the whole file is sent with 200
(RFC 9110 13.1.5). mdserver issues no ETags, so an ETag validator never
matches.

Every response carries `Server: mdserver/<package version>`, taken from
`package provide mdserver` rather than written out a second time.

---

## Health, logging, shutdown

`GET /__mdserver/health` returns `200 ok`, or `503 root unreadable` when the
document root is no longer a readable directory — it checks one thing rather
than only proving the process is alive, and reports nothing about the system.

The log writes one line per request, flushed immediately:

```
[09:15:03] 127.0.0.1 GET /index.md 200 6194 markdown
[09:15:03] 192.168.17.42 GET /handbuch.pdf 206 65536 bytes 0-65535/2400000
```

To stop a long-running server, use the control port via `mdctl.tcl`
(`tclsh mdctl.tcl --port 8099 stop`), which also works as a systemd
`ExecStop=` — see `mdserver.service.beispiel`. Listeners close first, running
responses get 5 s, then they are cut and that is logged. Note that
`echo stop | nc` hangs with OpenBSD netcat unless given `-N`.

---

## Security notes

- Self-signed certificates trigger browser warnings (use `mkcert` for trusted dev certs).
  `mkcert.tcl` writes a `subjectAltName` from the CN, and `--san` appends more —
  current browsers ignore the CN as a hostname, so a certificate without SAN is
  rejected even after import. Reaching the server by IP needs that IP in the SAN.
- No authentication built in — restrict access at network level for sensitive docs
- `--root` limits file access to the specified directory, **symlinks included**:
  every path component is resolved before it is compared against the root, so a
  link inside the tree that points outside it gets 403. A link that stays inside
  is served normally. The comparison goes up to the separator — `/srv/md` does
  not match `/srv/mdxyz`.
- Hidden files are off by default (`--dotfiles`), see above.
- Behind a proxy the peer address is always the proxy's. `X-Forwarded-For` is
  read **only** from peers listed in `--trusted-proxy` (empty by default, so
  the header is ignored), and only its **first** entry — anyone who reaches the
  port can append to that header. Set it in nginx with
  `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` and start
  mdserver with `--trusted-proxy 127.0.0.1`.

---

## .gitignore

Add generated certificate files:

```
server.crt
server.key
```

---

## File structure

```
tools/mdserver/
  mdserver.tcl       -- HTTP/HTTPS server
  mkcert.tcl         -- certificate helper
  mdctl.tcl          -- control port client (stop|ping)
  mdserver.service.beispiel -- sample systemd unit
  test/
    test-mdserver.tcl  -- 47 tests
  mdserver-demo/     -- demo site
```
