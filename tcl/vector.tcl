proc vadd {v w} {
    lmap x $v y $w { expr $x + $y }
}

proc vsub {v w} {
    lmap x $v y $w { expr $x - $y }
}

proc vneg {v} {
    lmap x $v { expr - $x }
}

proc vmul {c v} {
    lmap x $v { expr $c * $x }
}

proc dotProduct {v w} {
    lassign $v v1 v2 v3
    lassign $w w1 w2 w3
    expr $v1 * $w1 + $v2 * $w2 + $v3 * $w3
}

proc magnitude {v} {
    set x [dotProduct $v $v]
    expr { sqrt($x) }
}

proc normalize {v} {
    vmul [expr 1.0 / [magnitude $v]] $v
}

proc project {u v} {
    vmul [expr [dotProduct $u $v] / [dotProduct $v $v]] $v
}
