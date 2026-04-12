# pkgIndex.tcl -- mdstack 0.3.x
#
# Usage:
#   lappend auto_path /path/to/mdstack-0.3.x
#   package require mdparser 0.2
#   package require mdviewer 0.3

package ifneeded docir-md        0.1 [list source [file join $dir lib docir-md-0.1.tm]]
package ifneeded mdcontextmenu   0.1 [list source [file join $dir lib mdcontextmenu-0.1.tm]]
package ifneeded mdeditorkit     0.2 [list source [file join $dir lib mdeditorkit-0.2.tm]]
package ifneeded mdhtml          0.1 [list source [file join $dir lib mdhtml-0.1.tm]]
package ifneeded mdmodel         0.1 [list source [file join $dir lib mdmodel-0.1.tm]]
package ifneeded mdoutline       0.1 [list source [file join $dir lib mdoutline-0.1.tm]]
package ifneeded mdparser        0.2 [list source [file join $dir lib mdparser-0.2.tm]]
package ifneeded mdpdf           0.2 [list source [file join $dir lib mdpdf-0.2.tm]]
package ifneeded mdsearch        0.1 [list source [file join $dir lib mdsearch-0.1.tm]]
package ifneeded mdstack         0.1 [list source [file join $dir lib mdstack-0.1.tm]]
package ifneeded mdstacknoteskit 0.1 [list source [file join $dir lib mdstacknoteskit-0.1.tm]]
package ifneeded mdtext          0.1 [list source [file join $dir lib mdtext-0.1.tm]]
package ifneeded mdtheme         0.1 [list source [file join $dir lib mdtheme-0.1.tm]]
package ifneeded mdvalidator     0.1 [list source [file join $dir lib mdvalidator-0.1.tm]]
package ifneeded mdviewer        0.3 [list source [file join $dir lib mdviewer-0.3.tm]]
package ifneeded uicontextmenu   0.1 [list source [file join $dir lib uicontextmenu-0.1.tm]]

# pkgIndex.tcl -- mdstack vendors
package ifneeded pdf4tcllib 0.2 [list source [file join $dir vendors tm pdf4tcllib-0.2.tm]]