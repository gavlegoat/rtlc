import std/options
from std/math import sqrt
import vector

type
    Shape* = ref object of RootObj
        reflectivity: float
        color: Color

    Sphere* = ref object of Shape
        center: Point
        radius: float

    Plane* = ref object of Shape
        point: Point
        normal: Vector
        checkerboard: bool
        check_color: Option[Color]
        orientation: Option[Vector]

func reflectivity*(obj: Shape): float = return obj.reflectivity

method color*(obj: Shape, pt: Point): Color {.base.} =
    quit "not implemented"

method normal*(obj: Shape, pt: Point): Vector {.base.} =
    quit "not implemented"

method collision*(obj: Shape, pt: Point, dir: Vector): Option[float] {.base.} =
    quit "not implemented"

proc mkSphere*(refl: float, color: Color, center: Point, radius: float): Sphere =
    Sphere(reflectivity : refl,
           color : color,
           center : center,
           radius : radius)

method color*(obj: Sphere, pt: Point): Color = return obj.color

method normal*(obj: Sphere, pt: Point): Vector = return pt - obj.center

method collision*(obj: Sphere, pt: Point, dir: Vector): Option[float] =
    let a = dot(dir, dir)
    let v = pt - obj.center
    let b = 2 * dot(dir, v)
    let c = dot(v, v) - obj.radius * obj.radius
    let discr = b * b - 4 * a * c
    if discr < 0:
        return
    let t1 = (-b + sqrt(discr)) / (2 * a)
    let t2 = (-b - sqrt(discr)) / (2 * a)
    if t1 < 0:
        if t2 < 0:
            return
        return some(t2)
    if t2 < 0:
        return some(t1)
    return some(min(t1, t2))

proc mkPlane*(refl: float, color: Color, point: Point, normal: Vector): Plane =
    Plane(reflectivity : refl,
          color : color,
          point : point,
          normal : normal,
          checkerboard : false,
          checkColor : none(Color),
          orientation : none(Vector))

proc mkPlane*(refl: float, color: Color, point: Point, normal: Vector,
             chCol: Color, ori: Vector): Plane =
    Plane(reflectivity : refl,
          color : color,
          point : point,
          normal : normal,
          checkerboard : true,
          checkColor : some(chCol),
          orientation : some(ori))

method color*(obj: Plane, pt: Point): Color =
    if not obj.checkerboard:
        return obj.color
    let v = pt - obj.point
    let x = project(v, obj.orientation.get)
    let y = v - x
    let ix = (x.magnitude + 0.5).int
    let iy = (y.magnitude + 0.5).int
    if ((ix + iy) mod 2 + 2) mod 2 == 0:
        return obj.color
    return obj.check_color.get

method normal*(obj: Plane, pt: Point): Vector = return obj.normal

method collision*(obj: Plane, pt: Point, dir: Vector): Option[float] =
    let angle = dot(obj.normal, dir)
    if abs(angle) < 1e-6:
        return
    let t = dot(obj.normal, obj.point - pt) / angle
    if t < 0:
        return
    return some(t)
