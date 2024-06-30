package main

import "math"

type Point = [3]float64
type Vec = [3]float64
type Color = [3]float64

type Ray struct {
    Start Point
    Dir Vec
}

func VNeg(v Vec) Vec {
    var ret Vec
    for i := 0; i < 3; i++ {
        ret[i] = -v[i]
    }
    return ret
}

func VAdd(v, w Vec) Vec {
    var ret Vec
    for i := 0; i < 3; i++ {
        ret[i] = v[i] + w[i]
    }
    return ret
}

func VSub(v, w Vec) Vec {
    var ret Vec
    for i := 0; i < 3; i++ {
        ret[i] = v[i] - w[i]
    }
    return ret
}

func VMul(c float64, v Vec) Vec {
    var ret Vec
    for i := 0; i < 3; i++ {
        ret[i] = c * v[i];
    }
    return ret
}

func DotProduct(v, w Vec) float64 {
    total := 0.0
    for i := 0; i < 3; i++ {
        total += v[i] * w[i]
    }
    return total
}

func Magnitude(v Vec) float64 {
    return math.Sqrt(DotProduct(v, v))
}

func Normalize(v Vec) Vec {
    return VMul(1.0 / Magnitude(v), v)
}

func Project(v, w Vec) Vec {
    return VMul(DotProduct(v, w) / DotProduct(w, w), w)
}
