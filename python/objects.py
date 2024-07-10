from __future__ import annotations
from typing_extensions import override
from typing import Optional, List, Tuple
import math


class Color:

    def __init__(self, r: float, g: float, b: float):
        self.red = r
        self.green = g
        self.blue = b

    def __rmul__(self, a: float) -> Color:
        return Color(a * self.red, a * self.green, a * self.blue)

    def __add__(self, other: Color) -> Color:
        return Color(self.red + other.red,
                     self.green + other.green,
                     self.blue + other.blue)


class Point:

    def __init__(self, x: float, y: float, z: float):
        self.x = x
        self.y = y
        self.z = z

    def __sub__(self, p: Point) -> Vector:
        return Vector(self.x - p.x, self.y - p.y, self.z - p.z)

    def __add__(self, v: Vector) -> Point:
        return Point(self.x + v.x, self.y + v.y, self.z + v.z)

    def __str__(self) -> str:
        return "P(" + str(self.x) + ", " + str(self.y) + ", " + str(self.z) + ")"


class Vector:

    def __init__(self, x: float, y: float, z: float):
        self.x = x
        self.y = y
        self.z = z

    def __rmul__(self, a: float) -> Vector:
        return Vector(self.x * a, self.y * a, self.z * a)

    def __add__(self, other: Vector) -> Vector:
        return Vector(self.x + other.x,
                      self.y + other.y,
                      self.z + other.z)

    def __neg__(self) -> Vector:
        return Vector(-self.x, -self.y, -self.z)

    def __sub__(self, v: Vector) -> Vector:
        return Vector(self.x - v.x, self.y - v.y, self.z - v.z)

    def dot_product(self, v: Vector) -> float:
        return self.x * v.x + self.y * v.y + self.z * v.z

    def project(self, v: Vector) -> Vector:
        return self.dot_product(v) / v.dot_product(v) * v

    def magnitude(self) -> float:
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    def normalize(self) -> Vector:
        return 1 / self.magnitude() * self

    def __str__(self) -> str:
        return "V(" + str(self.x) + ", " + str(self.y) + ", " + str(self.z) + ")"



class Object:

    def __init__(self, refl: float, color: Color):
        self.reflectivity = refl
        self.color = color

    def get_color(self, pos: Point) -> Color:
        return self.color

    def get_normal_vector(self, pos: Point) -> Vector:
        raise NotImplementedError("get_normal_vector")

    def get_collision(self, start: Point, direction: Vector) -> Optional[float]:
        raise NotImplementedError("get_collision")


class Sphere(Object):

    def __init__(self, refl: float, color: Color, center: Point, radius: float):
        super().__init__(refl, color)
        self.center = center
        self.radius = radius

    @override
    def get_normal_vector(self, pos: Point) -> Vector:
        return pos - self.center

    @override
    def get_collision(self, start: Point, direction: Vector) -> Optional[float]:
        a = direction.dot_product(direction)
        v = start - self.center
        b = 2 * direction.dot_product(v)
        c = v.dot_product(v) - self.radius ** 2
        discr = b ** 2 - 4 * a * c
        if discr < 0:
            return None
        t1 = (-b + math.sqrt(discr)) / (2 * a)
        t2 = (-b - math.sqrt(discr)) / (2 * a)
        if t1 < 0:
            if t2 < 0:
                return None
            return t2
        if t2 < 0:
            return t1
        return min(t1, t2)


class Plane(Object):

    def __init__(self, refl: float, color: Color, point: Point, normal: Vector,
                 color2: Optional[Color] = None,
                 orientation: Optional[Vector] = None):
        super().__init__(refl, color)
        self.point = point
        self.normal = normal
        if color2 is not None:
            self.checkerboard = True
            self.color2 = color2
            self.orientation = orientation
        else:
            self.checkerboard = False

    @override
    def get_color(self, pos: Point) -> Color:
        if not self.checkerboard:
            return self.color
        v = pos - self.point
        x = v.project(self.orientation)
        y = v - x
        ix = round(x.magnitude())
        iy = round(y.magnitude())
        if (ix + iy) % 2 == 0:
            return self.color
        return self.color2

    @override
    def get_normal_vector(self, pos: Point) -> Vector:
        return self.normal

    @override
    def get_collision(self, start: Point, direction: Vector) -> Optional[float]:
        if abs(self.normal.dot_product(direction)) < 1e-6:
            return None
        t = self.normal.dot_product(self.point - start) / \
            self.normal.dot_product(direction)
        if t < 0:
            return None
        return t


class Scene:

    def __init__(self,
                 camera: Point,
                 light: Point,
                 antialias: int):
        self.camera = camera
        self.light = light
        self.ambient = 0.2
        self.specular = 0.5
        self.specular_power = 8
        self.max_reflections = 6
        self.background = Color(135, 206, 235)
        self.pixel_width = 512
        self.pixel_height = 512
        self.antialias = antialias
        self.objects: List[Object] = []

    def add_object(self, obj: Object) -> None:
        self.objects.append(obj)

    def nearest_intersection(self, start: Point, direction: Vector) \
            -> Optional[Tuple[float, Object]]:
        min_t = None
        obj = None
        for o in self.objects:
            t = o.get_collision(start, direction)
            if t is not None and (min_t is None or t < min_t):
                min_t = t
                obj = o
        if min_t is not None:
            assert obj is not None
            return min_t, obj
        return None
