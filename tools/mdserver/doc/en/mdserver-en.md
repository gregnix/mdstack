# mdserver

> Version 0.3

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
| `mdparser` | 0.2 | yes |
| `mdhtml` | 0.1 | yes |
| `mdtheme` | 0.1 | recommended |
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

---

## Troubleshooting

### Port already in use

```
ERROR: Cannot bind to HTTP port 8080: address already in use
```

Another process (e.g. a previous mdserver instance) is still holding the port.

```bash
# Release port 8080 immediately
fuser -k 8080/tcp

# Or: check first, then decide
fuser 8080/tcp        # shows PID
kill <PID>

# Alternative with lsof
lsof -ti:8080 | xargs kill
```

Then restart the server.

---

## Security notes

- Self-signed certificates trigger browser warnings (use `mkcert` for trusted dev certs)
- No authentication built in — restrict access at network level for sensitive docs
- `--root` limits file access to the specified directory

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
  test/
    test-mdserver.tcl  -- 47 tests
  mdserver-demo/     -- demo site
```
