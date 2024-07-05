import std/math

type
    Vector* = array[0..2, float]
    Point* = Vector
    Color* = Vector

func `+`*(u, v: Vector): Vector =
    for i in 0..2: result[i] = u[i] + v[i]

proc `+=`*(u: var Vector, v: Vector) =
    for i in 0..2: u[i] += v[i]

func `-`*(u, v: Vector): Vector =
    for i in 0..2: result[i] = u[i] - v[i]

func `-`*(v: Vector): Vector =
    for i in 0..2: result[i] = -v[i]

func `*`*(x: float, v: Vector): Vector =
    for i in 0..2: result[i] = x * v[i]

func dot*(u, v: Vector): float =
    for i in 0..2: result += u[i] * v[i]

func magnitude*(v: Vector): float =
    return sqrt(dot(v, v))

func normalize*(v: Vector): Vector =
    return (1.0 / v.magnitude) * v

func project*(u, v: Vector): Vector =
    return dot(u, v) / dot(v, v) * v
