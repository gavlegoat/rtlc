using LinearAlgebra

abstract type Shape end

const Vec = Vector{Real}
const Point = Vector{Real}
const Color = Vector{Real}

function project(u, v)
    dot(u, v) / dot(v, v) * v
end

function normalize(v)
    v / norm(v)
end

struct ShapeBase
    color :: Color
    reflectivity :: Real
end

struct Sphere <: Shape
    base :: ShapeBase
    center :: Point
    radius :: Real
end

struct Plane <: Shape
    base :: ShapeBase
    point :: Point
    normal :: Vec
    check_color :: Union{Color, Nothing}
    orientation :: Union{Vec, Nothing}
end

function getnormal(obj :: Sphere, pt)
    pt - obj.center
end

function getcolor(obj :: Sphere, pt)
    obj.base.color
end

function getintersection(obj :: Sphere, pt, dir)
    a = dot(dir, dir)
    v = pt - obj.center
    b = 2 * dot(dir, v)
    c = dot(v, v) - obj.radius ^ 2
    discr = b ^ 2 - 4 * a * c
    if discr < 0
        return nothing
    end
    t1 = (-b + sqrt(discr)) / (2 * a)
    t2 = (-b - sqrt(discr)) / (2 * a)
    if t1 < 0
        if t2 < 0
            nothing
        else
            t2
        end
    else
        if t2 < 0
            t1
        else
            min(t1, t2)
        end
    end
end

function getnormal(obj :: Plane, pt)
    obj.normal
end

function getcolor(obj :: Plane, pt)
    if isnothing(obj.check_color)
        return obj.base.color
    end
    v = pt - obj.point
    vx = project(v, obj.orientation)
    vy = v - vx
    if (round(norm(vx)) + round(norm(vy))) % 2 == 0
        obj.base.color
    else
        obj.check_color
    end
end

function getintersection(obj :: Plane, pt, dir)
    angle = dot(obj.normal, dir)
    if abs(angle) < 1e-6
        return nothing
    end
    t = dot(obj.point - pt, obj.normal) / angle
    t < 0 ? nothing : t
end
