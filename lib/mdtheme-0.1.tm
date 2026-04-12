# mdtheme-0.1.tm
# (c) 2026 Gregor Ebbing -- MIT License (see LICENSE)
#
# Color scheme system for mdviewer und mdhelp.
# Defines theme dicts with all colors for viewer, editor, TIP-700.
#
# API:
#   mdtheme::names               -> Liste aller Themes
#   mdtheme::current              -> Name des aktiven Themes
#   mdtheme::get key              -> Color value from active theme
#   mdtheme::set name             -> Activate theme
#   mdtheme::theme name           -> Ganzes Theme-Dict
#   mdtheme::applyToViewer path   -> Apply colors to mdviewer
#   mdtheme::applyToText widget   -> Apply colors to text widget

package provide mdtheme 0.1

namespace eval mdtheme {
    namespace export names current activate color theme applyToViewer applyToText applyToViewer applyToText
    variable currentTheme "hell"
    variable themes
    array set themes {}
}

# ============================================================
# Theme-Definitionen
# ============================================================

# --- Hell (Standard) ---
set mdtheme::themes(hell) {
    name            "Hell"
    bg              "#ffffff"
    fg              "#000000"
    bg_alt          "#f5f5f5"
    fg_dim          "#666666"
    fg_muted        "#888888"
    fg_dark         "#333333"
    fg_accent       "#444444"
    link            "#0066cc"
    link_visited    "#551a8b"
    link_pdf        "#cc6600"
    hr              "#777777"
    quote_fg        "#555555"
    quote_bg        "#f0f0f0"
    code_bg         "#e8e8e8"
    code_inline_bg  "#f0f0f0"
    code_label_fg   "#666666"
    code_label_bg   "#e0e0e0"
    table_bg        "#fafafa"
    table_header_bg "#e8e8e8"
    table_header_fg "#333333"
    table_code_bg   "#e0e0e0"
    image_fg        "#666666"
    caption_fg      "#888888"
    listprefix_fg   "#444444"
    task_done_fg    "#999999"
    syn_keyword     "#1a5276"
    syn_string      "#196f3d"
    syn_comment     "#888888"
    syn_variable    "#7b241c"
    syn_option      "#6c3483"
    syn_number      "#a04000"
    span_cmd        "#1a5276"
    span_sub        "#1a5276"
    span_lit        "#1a5276"
    span_optlit     "#5b7fa5"
    span_arg        "#196f3d"
    span_optarg     "#4a8c6a"
    span_optdot     "#4a8c6a"
    span_ins        "#6c3483"
    span_ccmd       "#7b241c"
    span_cargs      "#a04000"
    span_ret        "#a04000"
    div_synopsis    "#e8f0fe"
    div_example     "#f0f8f0"
    div_arguments   "#fef9e7"
    div_note        "#fef3e2"
    div_warning     "#fdedec"
    outline_hl      "#fff3cd"
    status_error    "#cc0000"
    status_ok       "#008800"
}

# --- Dunkel ---
set mdtheme::themes(dunkel) {
    name            "Dunkel"
    bg              "#1e1e2e"
    fg              "#cdd6f4"
    bg_alt          "#282838"
    fg_dim          "#a0a0b8"
    fg_muted        "#7f849c"
    fg_dark         "#bac2de"
    fg_accent       "#a6adc8"
    link            "#89b4fa"
    link_visited    "#cba6f7"
    link_pdf        "#fab387"
    hr              "#585b70"
    quote_fg        "#a6adc8"
    quote_bg        "#313244"
    code_bg         "#313244"
    code_inline_bg  "#2a2a3c"
    code_label_fg   "#7f849c"
    code_label_bg   "#313244"
    table_bg        "#282838"
    table_header_bg "#313244"
    table_header_fg "#cdd6f4"
    table_code_bg   "#2a2a3c"
    image_fg        "#a6adc8"
    caption_fg      "#7f849c"
    listprefix_fg   "#a6adc8"
    task_done_fg    "#585b70"
    syn_keyword     "#89b4fa"
    syn_string      "#a6e3a1"
    syn_comment     "#585b70"
    syn_variable    "#f38ba8"
    syn_option      "#cba6f7"
    syn_number      "#fab387"
    span_cmd        "#89b4fa"
    span_sub        "#89b4fa"
    span_lit        "#89b4fa"
    span_optlit     "#74c7ec"
    span_arg        "#a6e3a1"
    span_optarg     "#94e2d5"
    span_optdot     "#94e2d5"
    span_ins        "#cba6f7"
    span_ccmd       "#f38ba8"
    span_cargs      "#fab387"
    span_ret        "#fab387"
    div_synopsis    "#1e2a3e"
    div_example     "#1e2e1e"
    div_arguments   "#2e2a1e"
    div_note        "#2e261e"
    div_warning     "#2e1e1e"
    outline_hl      "#45475a"
    status_error    "#f38ba8"
    status_ok       "#a6e3a1"
}

# --- Solarized ---
set mdtheme::themes(solarized) {
    name            "Solarized"
    bg              "#fdf6e3"
    fg              "#657b83"
    bg_alt          "#eee8d5"
    fg_dim          "#93a1a1"
    fg_muted        "#93a1a1"
    fg_dark         "#586e75"
    fg_accent       "#586e75"
    link            "#268bd2"
    link_visited    "#6c71c4"
    link_pdf        "#cb4b16"
    hr              "#93a1a1"
    quote_fg        "#586e75"
    quote_bg        "#eee8d5"
    code_bg         "#eee8d5"
    code_inline_bg  "#eee8d5"
    code_label_fg   "#93a1a1"
    code_label_bg   "#eee8d5"
    table_bg        "#fdf6e3"
    table_header_bg "#eee8d5"
    table_header_fg "#586e75"
    table_code_bg   "#eee8d5"
    image_fg        "#586e75"
    caption_fg      "#93a1a1"
    listprefix_fg   "#586e75"
    task_done_fg    "#93a1a1"
    syn_keyword     "#268bd2"
    syn_string      "#859900"
    syn_comment     "#93a1a1"
    syn_variable    "#dc322f"
    syn_option      "#6c71c4"
    syn_number      "#cb4b16"
    span_cmd        "#268bd2"
    span_sub        "#268bd2"
    span_lit        "#268bd2"
    span_optlit     "#2aa198"
    span_arg        "#859900"
    span_optarg     "#2aa198"
    span_optdot     "#2aa198"
    span_ins        "#6c71c4"
    span_ccmd       "#dc322f"
    span_cargs      "#cb4b16"
    span_ret        "#cb4b16"
    div_synopsis    "#e8f0e3"
    div_example     "#eef6e3"
    div_arguments   "#f6f0d5"
    div_note        "#f6edd5"
    div_warning     "#f6e3d5"
    outline_hl      "#eee8d5"
    status_error    "#dc322f"
    status_ok       "#859900"
}

# ============================================================
# API
# ============================================================

proc mdtheme::names {} {
    variable themes
    return [lsort [array names themes]]
}

proc mdtheme::current {} {
    variable currentTheme
    return $currentTheme
}

proc mdtheme::activate {name} {
    variable themes
    variable currentTheme
    if {![info exists themes($name)]} {
        error "mdtheme: unknown theme '$name' (available: [mdtheme::names])"
    }
    set currentTheme $name
}

proc mdtheme::color {key} {
    variable themes
    variable currentTheme
    set t $themes($currentTheme)
    if {[dict exists $t $key]} {
        return [dict get $t $key]
    }
    error "mdtheme: unknown key '$key' in theme '$currentTheme'"
}

proc mdtheme::theme {name} {
    variable themes
    if {![info exists themes($name)]} {
        error "mdtheme: unknown theme '$name'"
    }
    return $themes($name)
}

# Apply colors to mdviewer text widget
proc mdtheme::applyToViewer {path} {
    variable currentTheme
    variable themes
    set t [mdviewer::widget $path]
    set th $themes($currentTheme)

    # Text-Widget Hintergrund + Vordergrund
    $t configure -background [dict get $th bg] -foreground [dict get $th fg]

    # Update tag colors
    foreach {tag key} {
        link         link
        pdflink      link_pdf
        listprefix   listprefix_fg
        taskdone     task_done_fg
        hr           hr
        quote        quote_fg
        imageblock   image_fg
        imgcaption   caption_fg
        imageinline  image_fg
        codeinline   code_inline_bg
        codelabel    code_label_fg
        codeblock    code_bg
        tablecell    table_bg
        tableheader  table_header_bg
        code_t       table_code_bg
        syn_keyword  syn_keyword
        syn_string   syn_string
        syn_comment  syn_comment
        syn_variable syn_variable
        syn_option   syn_option
        syn_number   syn_number
    } {
        catch {
            set color [dict get $th $key]
            # Entscheiden ob foreground oder background
            if {$key in {code_inline_bg code_bg table_bg table_header_bg table_code_bg}} {
                $t tag configure $tag -background $color
            } else {
                $t tag configure $tag -foreground $color
            }
        }
    }

    # Quote + Codeblock: extra background
    catch { $t tag configure quote -background [dict get $th quote_bg] }
    catch { $t tag configure codelabel -background [dict get $th code_label_bg] }
    catch { $t tag configure codeblock -background [dict get $th code_bg] }
    catch {
        $t tag configure tableheader -foreground [dict get $th table_header_fg] \
            -background [dict get $th table_header_bg]
    }
}

# Apply colors to any text widget (editor)
proc mdtheme::applyToText {t} {
    variable currentTheme
    variable themes
    set th $themes($currentTheme)
    $t configure -background [dict get $th bg] -foreground [dict get $th fg] \
        -insertbackground [dict get $th fg]
}

# ============================================================
# Typography-Erweiterung fuer HTML und PDF (0.2)
# ============================================================
#
# Jedes Theme bekommt optionale Typography-Schluessel.
# Falls nicht vorhanden: Defaults aus _typographyDefaults.
#
# Schluessel:
#   font_body       Brottext-Font (PDF: Fontname, HTML: font-family)
#   font_heading    Ueberschriften-Font
#   font_mono       Monospace-Font
#   font_size       Basis-Schriftgroesse in pt
#   line_spacing    Zeilenabstand-Faktor (1.4 = 140%)
#   margin_page     Seitenrand in pt (fuer PDF)
#   heading_scale   Liste mit 6 Faktoren fuer H1-H6
#   space_before    Abstand vor H1-H6 in pt
#   space_after     Abstand nach H1-H6 in pt
#   max_width_px    Maximale Breite fuer HTML in px

namespace eval mdtheme {
    variable _typographyDefaults {
        font_body       "Georgia, 'Times New Roman', serif"
        font_heading    "Helvetica, Arial, sans-serif"
        font_mono       "'Courier New', Courier, monospace"
        font_size       11
        line_spacing    1.4
        margin_page     50
        heading_scale   {1.6 1.4 1.2 1.1 1.0 1.0}
        space_before    {12 8 6 4 2 0}
        space_after     {6 4 4 2 2 0}
        max_width_px    860
    }
}

# Liefert Wert aus Theme (Farbe oder Typography), mit Fallback auf Default
proc mdtheme::get {name key} {
    variable themes
    variable _typographyDefaults
    if {![info exists themes($name)]} {
        error "mdtheme: unknown theme '$name'"
    }
    set th $themes($name)
    if {[dict exists $th $key]} {
        return [dict get $th $key]
    }
    if {[dict exists $_typographyDefaults $key]} {
        return [dict get $_typographyDefaults $key]
    }
    error "mdtheme: unknown key '$key' in theme '$name'"
}

# Konvertiert Theme -> vollstaendiges CSS fuer mdhtml
proc mdtheme::toCSS {{name ""}} {
    variable currentTheme
    variable themes
    variable _typographyDefaults
    if {$name eq ""} { set name $currentTheme }
    if {![info exists themes($name)]} {
        error "mdtheme: unknown theme '$name'"
    }
    set th $themes($name)

    # Hilfsproc: Wert aus Theme oder Default
    proc _tv {th key} {
        upvar _typographyDefaults def
        if {[dict exists $th $key]} { return [dict get $th $key] }
        return [dict get $def $key]
    }
    set def $_typographyDefaults

    set bg         [dict get $th bg]
    set fg         [dict get $th fg]
    set bg_alt     [dict get $th bg_alt]
    set link       [dict get $th link]
    set code_bg    [dict get $th code_bg]
    set code_ibg   [dict get $th code_inline_bg]
    set quote_fg   [dict get $th quote_fg]
    set quote_bg   [dict get $th quote_bg]
    set tbl_hbg    [dict get $th table_header_bg]
    set tbl_hfg    [dict get $th table_header_fg]
    set hr_col     [dict get $th hr]
    set caption_fg [dict get $th caption_fg]
    set task_fg    [dict get $th task_done_fg]

    set font_body    [_tv $th font_body]
    set font_heading [_tv $th font_heading]
    set font_mono    [_tv $th font_mono]
    set font_size    [_tv $th font_size]
    set line_sp      [_tv $th line_spacing]
    set max_w        [_tv $th max_width_px]

    # Span-Farben
    set span_cmd  [expr {[dict exists $th span_cmd]  ? [dict get $th span_cmd]  : $link}]
    set span_arg  [expr {[dict exists $th span_arg]  ? [dict get $th span_arg]  : $fg}]
    set span_lit  [expr {[dict exists $th span_lit]  ? [dict get $th span_lit]  : $link}]

    return "
body {
    font-family: $font_body;
    font-size: ${font_size}pt;
    line-height: $line_sp;
    color: $fg;
    background: $bg;
    max-width: ${max_w}px;
    margin: 0 auto;
    padding: 2rem 1.5rem;
}
h1, h2, h3, h4, h5, h6 {
    font-family: $font_heading;
    margin-top: 1.8rem;
    margin-bottom: 0.4rem;
    line-height: 1.2;
    color: $fg;
}
h1 { font-size: 2em;   border-bottom: 2px solid $hr_col; padding-bottom: 0.2rem; }
h2 { font-size: 1.5em; border-bottom: 1px solid $hr_col; padding-bottom: 0.1rem; }
h3 { font-size: 1.2em; }
h4 { font-size: 1.1em; }
p  { margin: 0.7rem 0; }
a  { color: $link; text-decoration: none; }
a:hover { text-decoration: underline; }
code {
    font-family: $font_mono;
    font-size: 0.88em;
    background: $code_ibg;
    padding: 0.1em 0.3em;
    border-radius: 3px;
}
pre {
    font-family: $font_mono;
    font-size: 0.88em;
    background: $code_bg;
    border-radius: 4px;
    padding: 1rem;
    overflow-x: auto;
    margin: 1rem 0;
}
pre code { background: none; padding: 0; }
blockquote {
    border-left: 4px solid $hr_col;
    margin: 1rem 0;
    padding: 0.4rem 1rem;
    color: $quote_fg;
    background: $quote_bg;
}
table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
th, td { border: 1px solid $hr_col; padding: 0.45rem 0.7rem; }
th { background: $tbl_hbg; color: $tbl_hfg; font-weight: bold; }
tr:nth-child(even) { background: $bg_alt; }
ul, ol { padding-left: 1.5rem; margin: 0.5rem 0; }
li { margin: 0.2rem 0; }
dl { margin: 1rem 0; }
dt { font-weight: bold; margin-top: 0.5rem; }
dd { margin-left: 1.5rem; color: $quote_fg; }
hr { border: none; border-top: 1px solid $hr_col; margin: 2rem 0; }
img { max-width: 100%; height: auto; }
figure { margin: 1rem 0; text-align: center; }
figcaption { font-size: 0.85em; color: $caption_fg; margin-top: 0.3rem; }
.toc-container {
    background: $bg_alt;
    border: 1px solid $hr_col;
    border-radius: 4px;
    padding: 0.8rem 1.2rem;
    margin-bottom: 2rem;
}
.toc ul { list-style: none; padding-left: 0; margin: 0; }
.toc li { margin: 0.2rem 0; }
.toc-h2 { padding-left: 1rem; }
.toc-h3 { padding-left: 2rem; }
.footnotes { font-size: 0.88em; color: $quote_fg; margin-top: 3rem; }
sup a { font-size: 0.75em; }
input\[type=\"checkbox\"\] { margin-right: 0.3em; }
span.cmd  { color: $span_cmd; font-family: $font_mono; font-weight: bold; }
span.arg  { color: $span_arg; font-style: italic; }
span.lit  { color: $span_lit; font-family: $font_mono; }
span.opt  { opacity: 0.75; }
"
}

# Liefert PDF-Optionen als Dict fuer mdpdf
proc mdtheme::toPdfOpts {{name ""}} {
    variable currentTheme
    variable themes
    variable _typographyDefaults
    if {$name eq ""} { set name $currentTheme }
    if {![info exists themes($name)]} {
        error "mdtheme: unknown theme '$name'"
    }
    set th $themes($name)
    proc _tv2 {th key} {
        upvar _typographyDefaults def
        if {[dict exists $th $key]} { return [dict get $th $key] }
        return [dict get $def $key]
    }
    set def $_typographyDefaults
    return [dict create \
        fontsize    [_tv2 $th font_size] \
        margin      [_tv2 $th margin_page] \
        colorLink   [dict get $th link] \
        colorCode   [dict get $th code_bg] \
    ]
}
