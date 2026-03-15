#!/usr/bin/env tclsh
# mdhtml-themes-demo.tcl
# Demonstriert mdhtml mit verschiedenen mdtheme-Themes
# und der Kombination Theme + externe CSS-Overrides.
#
# Erzeugt:
#   mdhtml-theme-hell.html       -- Theme hell
#   mdhtml-theme-dunkel.html     -- Theme dunkel
#   mdhtml-theme-solarized.html  -- Theme solarized
#   mdhtml-theme-custom.html     -- Theme hell + custom.css Overrides
#
# Requires: mdparser 0.2, mdtheme 0.1, mdhtml 0.1

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir .. lib]]

package require mdparser 0.2
package require mdtheme  0.1
package require mdhtml   0.1

set outdir [file join $scriptDir html]
file mkdir $outdir

set markdown {
# mdhtml Theme Demo

Demonstrates **mdhtml** with different **mdtheme** color themes.

## Text Formatting

**Bold**, *italic*, ***bold italic***, ~~strikethrough~~.

`Inline code` with monospace font.

A paragraph with a [clickable link](https://www.tcl.tk) and
another [link to GitHub](https://github.com/gregnix/pdf4tcl).

## Blockquote

> This is an important quote demonstrating
> the blockquote style of the current theme.

## Code Block

```tcl
# Theme only
mdhtml::export $ast output.html -theme hell

# Theme + CSS overrides (combined)
mdhtml::export $ast output.html -theme hell -css custom.css
```

## Table

| Feature       | mdhtml | mdpdf | mdviewer |
|---------------|:------:|:-----:|:--------:|
| Themes        | yes    | yes   | yes      |
| CSS Overrides | yes    | --    | --       |
| TOC           | yes    | yes   | yes      |
| Hyperlinks    | yes    | yes   | yes      |
| Footnotes     | yes    | no    | no       |

## Lists

- Item one
- **Item two** with bold
- Item with [link](https://tcl.tk)

1. First
2. Second

Task list:

- [x] mdhtml renderer
- [x] mdtheme integration
- [x] theme + css combination
- [ ] syntax highlighting

## Definition List

mdhtml
: Markdown to HTML renderer for mdstack.

mdtheme
: Shared theme system for HTML, PDF and Tk.

---

*Generated with mdhtml 0.1 + mdtheme 0.1*
}

set ast [mdparser::parse $markdown]

# --- 1. Alle Themes ---
foreach theme [mdtheme::names] {
    set outfile [file join $outdir "mdhtml-theme-${theme}.html"]
    mdhtml::export $ast $outfile \
        -title "mdhtml -- Theme: $theme" \
        -theme $theme \
        -toc   1 \
        -lang  en
    puts "Written: $outfile  (theme: $theme)"
}

# --- 2. Theme + externe CSS-Overrides ---
set cssFile [file join $outdir "mdhtml-custom.css"]
set fh [open $cssFile w]
puts $fh {/* Custom CSS Overrides -- ergaenzt Theme hell */
body {
    font-size: 13pt;
    max-width: 700px;
    font-family: 'Palatino Linotype', Palatino, serif;
}
h1 {
    color: #8b0000;
    border-bottom: 3px solid #8b0000;
    font-size: 2.2em;
}
h2 { color: #5c3317; }
a  { color: #8b0000; font-weight: bold; }
blockquote {
    border-left: 4px solid #8b0000;
    background: #fff8f0;
}
table th { background: #8b0000; color: white; }
}
close $fh

set outfile [file join $outdir "mdhtml-theme-custom.html"]
mdhtml::export $ast $outfile \
    -title "mdhtml -- Theme hell + custom overrides" \
    -theme hell \
    -css   $cssFile \
    -toc   1 \
    -lang  en
puts "Written: $outfile  (theme: hell + custom.css)"

puts "\nOpen in browser:"
foreach theme [mdtheme::names] {
    puts "  [file join $outdir mdhtml-theme-${theme}.html]"
}
puts "  [file join $outdir mdhtml-theme-custom.html]  (with overrides)"
