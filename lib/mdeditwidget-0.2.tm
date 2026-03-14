package require Tk
package require mdeditorkit 0.2

package provide mdeditwidget 0.2

namespace eval mdeditwidget {
    namespace export create settext gettext setmode mode model setmodel getdocmodel configure cget widgets
    variable state
    array set state {}
}

proc mdeditwidget::create {path args} {
    variable state

    ttk::frame $path
    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 1 -weight 1

    # Toolbar
    set tb [ttk::frame $path.tb]
    ttk::button $tb.edit    -text "Edit"    -command [list mdeditwidget::setmode $path edit]
    ttk::button $tb.preview -text "Preview" -command [list mdeditwidget::setmode $path preview]
    ttk::button $tb.split   -text "Split"   -command [list mdeditwidget::setmode $path split]

    grid $tb.edit $tb.preview $tb.split -sticky w -padx 4 -pady 4
    grid columnconfigure $tb 3 -weight 1

    # Main kit
    set kit [mdeditorkit::create $path.kit]
    grid $tb  -row 0 -column 0 -sticky ew
    grid $kit -row 1 -column 0 -sticky nsew

    set state($path,tb)  $tb
    set state($path,kit) $kit

    mdeditwidget::configure $path {*}$args
    return $path
}

proc mdeditwidget::widgets {path} {
    variable state
    set d [mdeditorkit::widgets $state($path,kit)]
    dict set d toolbar $state($path,tb)
    dict set d kit $state($path,kit)
    return $d
}

proc mdeditwidget::configure {path args} {
    variable state
    if {[llength $args] == 0} { return }
    mdeditorkit::configure $state($path,kit) {*}$args
}

proc mdeditwidget::cget {path option} {
    variable state
    return [mdeditorkit::cget $state($path,kit) $option]
}

proc mdeditwidget::settext {path markdown} {
    variable state
    mdeditorkit::settext $state($path,kit) $markdown
}

proc mdeditwidget::gettext {path} {
    variable state
    return [mdeditorkit::gettext $state($path,kit)]
}

proc mdeditwidget::setmode {path m} {
    variable state
    mdeditorkit::setmode $state($path,kit) $m
}

proc mdeditwidget::mode {path} {
    variable state
    return [mdeditorkit::mode $state($path,kit)]
}

proc mdeditwidget::model {path} {
    variable state
    return [mdeditorkit::model $state($path,kit)]
}

proc mdeditwidget::setmodel {path m} {
    variable state
    mdeditorkit::setmodel $state($path,kit) $m
}

proc mdeditwidget::getdocmodel {path} {
    variable state
    return [mdeditorkit::getdocmodel $state($path,kit)]
}
