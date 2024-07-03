source shapes.tcl

package require Tcl 8.4
package require json
package require Tk

# We're using Tk for writing image files, but importing Tk automatically opens
# a window. This command hides that window.
wm withdraw .

proc nearestIntersection {scene pt dir} {
    set objs [dict get $scene objects]
    foreach o $objs {
        set time [collisionTime $o $pt $dir]
        if {$time < 0} {
            continue
        }
        if {![info exists minTime] || ($time < $minTime)} {
            set minTime $time
            set bestObj $o
        }
    }
    if {[info exists minTime]} {
        return [dict create time $minTime object $bestObj]
    }
    return [dict create]
}

proc inShadow {scene pt} {
    set lightDir [vsub [dict get $scene light] $pt]
    set start [vadd $pt [vmul 0.000001 $lightDir]]
    set res [nearestIntersection $scene $start $lightDir]
    dict exists $res time
}

proc colorRay {scene pt dir refls} {
    set res [nearestIntersection $scene $pt $dir]
    if {![dict exists $res time]} {
        return [dict get $scene background]
    }
    set t [dict get $res time]
    set obj [dict get $res object]
    set col [vadd [vmul $t $dir] $pt]
    set refl [dict get $obj reflectivity]
    set amb [expr [dict get $scene ambient] * (1 - $refl)]
    set color [color $obj $col]
    set lighting [vmul $amb $color]
    set norm [normalize [normal $obj $col]]
    set op [normalize [vneg $dir]]
    if {![inShadow $scene $col]} {
        set lightDir [normalize [vsub [dict get $scene light] $col]]
        set factor [expr (1 - $amb) * (1 - $refl)]
        set factor [expr $factor * max(0, [dotProduct $norm $lightDir])]
        set lighting [vadd $lighting [vmul $factor $color]]
        set half [normalize [vadd $lightDir $op]]
        set sp [dict get $scene specularPower]
        set factor [expr pow(max(0, [dotProduct $half $norm]), $sp)]
        set factor [expr $factor * [dict get $scene specular]]
        set lighting [vadd $lighting [vmul $factor [list 255 255 255]]]
    }
    if {($refls < [dict get $scene maxRefls]) && ($refl > 0.003)} {
        set ref [vadd $op [vmul 2 [vsub [project $op $norm] $op]]]
        set npt [vadd $col [vmul 0.000001 $ref]]
        set reflColor [colorRay $scene $npt $ref [expr 1 + $refls]]
        set lighting [vadd $lighting [vmul [expr (1 - $amb) * $refl] $reflColor]]
    }
    return $lighting
}

proc colorPoint {scene pt} {
    colorRay $scene $pt [vsub $pt [dict get $scene camera]] 0
}

proc colorPixel {scene x y scale antialias} {
    set color [list 0 0 0]
    for {set i 0} {$i < $antialias} {incr i} {
        set rx [expr ($x + rand()) / $scale]
        set ry [expr 1 - ($y + rand()) / $scale]
        set c [colorPoint $scene [list $rx 0 $ry]]
        set color [vadd $color $c]
    }
    return [vmul [expr 1.0 / $antialias] $color]
}

proc parseScene {filename} {
    set infile [open $filename]
    set data [read $infile]
    close $infile
    set json [::json::json2dict $data]
    set json [dict merge $json [dict create \
        ambient 0.2 \
        specular 0.5 \
        specularPower 8 \
        maxRefls 6 \
        background {135 206 235} \
    ]]
    set ret [dict create scene $json antialias [dict get $json antialias]]
    return $ret
}

proc convert {x} {
    format %02x [expr min(255, max(0, round($x)))]
}

if {$argc != 2} {
    puts "Usage: tclsh main.tcl <config-file> <output-file>"
} else {
    set res [parseScene [lindex $argv 0]]
    set scene [dict get $res scene]
    set antialias [dict get $res antialias]
    set width 512
    set height 512
    set img [image create photo -width $width -height $height]
    set data {}
    for {set i 0} {$i < $height} {incr i} {
        puts $i
        set row {}
        for {set j 0} {$j < $width} {incr j} {
            set color [colorPixel $scene $j $i $width $antialias]
            set r [convert [lindex $color 0]]
            set g [convert [lindex $color 1]]
            set b [convert [lindex $color 2]]
            set encoded #$r$g$b
            lappend row $encoded
        }
        lappend data $row
    }
    $img put $data -t 0 0
    $img write [lindex $argv 1] -background blue
    exit
}
