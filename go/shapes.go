package main

import "math"

type Shape interface {
    Reflectivity() float64
    Color(Point) Color
    Normal(Point) Vec
    Collision(Ray) float64
}

type Sphere struct {
    refl float64
    col Color
    center Point
    radius float64
}

func (self Sphere) Reflectivity() float64 {
    return self.refl
}

func (self Sphere) Color(p Point) Color {
    return self.col
}

func (self Sphere) Normal(p Point) Vec {
    return VSub(p, self.center)
}

func (self Sphere) Collision(r Ray) float64 {
    a := DotProduct(r.Dir, r.Dir)
    v := VSub(r.Start, self.center)
    b := 2 * DotProduct(r.Dir, v)
    c := DotProduct(v, v) - self.radius * self.radius
    discr := b * b - 4 * a * c
    if discr < 0 {
        return -1
    }
    t1 := (-b + math.Sqrt(discr)) / (2 * a)
    t2 := (-b - math.Sqrt(discr)) / (2 * a)
    if t1 < 0 {
        return t2
    }
    if t2 < 0 {
        return t1
    }
    return math.Min(t1, t2)
}

type Plane struct {
    refl float64
    col Color
    point Point
    norm Vec
    checkerboard bool
    checkColor Color
    orientation Vec
}

func (self Plane) Reflectivity() float64 {
    return self.refl
}

func (self Plane) Color(p Point) Color {
    if !self.checkerboard {
        return self.col
    }
    v := VSub(p, self.point)
    x := Project(v, self.orientation)
    y := VSub(v, x)
    ix := int(Magnitude(x) + 0.5)
    iy := int(Magnitude(y) + 0.5)
    if (ix + iy) % 2 == 0 {
        return self.checkColor
    }
    return self.col
}

func (self Plane) Normal(p Point) Vec {
    return self.norm
}

func (self Plane) Collision(r Ray) float64 {
    angle := DotProduct(r.Dir, self.norm)
    if math.Abs(angle) < 1e-6 {
        return -1
    }
    return DotProduct(self.norm, VSub(self.point, r.Start)) / angle
}
