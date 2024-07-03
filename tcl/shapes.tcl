# All shapes are represented as dictionaries. Each shape has a "type"
# key which is either "sphere" or "plane". Other keys are determined by the
# type of the object.

source vector.tcl

proc planeColor {obj pt} {
    if {[dict get $obj checkerboard]} {
        set v [vsub $pt [dict get $obj point]]
        set x [project $v [dict get $obj orientation]]
        set y [vsub $v $x]
        set ix [expr round([magnitude $x])]
        set iy [expr round([magnitude $y])]
        if {($ix + $iy) % 2 == 0} {
            dict get $obj color
        } else {
            dict get $obj color2
        }
    } else {
        dict get $obj color
    }
}

proc sphereColor {obj} {
    dict get $obj color
}

proc color {obj pt} {
    if {[dict get $obj type] == "plane"} {
        planeColor $obj $pt
    } else {
        sphereColor $obj
    }
}

proc planeNormal {obj} {
    dict get $obj normal
}

proc sphereNormal {obj pt} {
    vsub $pt [dict get $obj center]
}

proc normal {obj pt} {
    if {[dict get $obj type] == "plane"} {
        planeNormal $obj
    } else {
        sphereNormal $obj $pt
    }
}

proc sphereCollisionTime {obj pt dir} {
    set a [dotProduct $dir $dir]
    set v [vsub $pt [dict get $obj center]]
    set b [expr 2 * [dotProduct $dir $v]]
    set c [expr [dotProduct $v $v] - pow([dict get $obj radius], 2)]
    set discr [expr $b * $b - 4 * $a * $c]
    if {$discr < 0} {
        return -1
    }
    set t1 [expr (-$b + sqrt($discr)) / (2 * $a)]
    set t2 [expr (-$b - sqrt($discr)) / (2 * $a)]
    if {$t1 < 0} {
        return $t2
    } elseif {$t2 < 0} {
        return $t1
    } else {
        expr min($t1, $t2)
    }
}

proc planeCollisionTime {obj pt dir} {
    set norm [dict get $obj normal]
    set angle [dotProduct $norm $dir]
    if {abs($angle) < 0.000001} {
        return -1
    }
    set v [vsub [dict get $obj point] $pt]
    expr [dotProduct $norm $v] / $angle
}

proc collisionTime {obj pt dir} {
    if {[dict get $obj type] == "plane"} {
        planeCollisionTime $obj $pt $dir
    } else {
        sphereCollisionTime $obj $pt $dir
    }
}
