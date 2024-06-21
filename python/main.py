import json
import sys
import random
from PIL import Image

from objects import Scene, Vector, Point, Color, Sphere, Plane, Object


def parse_scene(filename: str) -> Scene:
    with open(filename, 'r') as json_file:
        data = json.load(json_file)
    scene = Scene(Point(data["camera"][0], data["camera"][1], data["camera"][2]),
                  Point(data["light"][0], data["light"][1], data["light"][2]),
                  data["antialias"])
    for o in data["objects"]:
        if o["type"] == "sphere":
            obj: Object = \
                Sphere(o["reflectivity"],
                       Color(o["color"][0], o["color"][1], o["color"][2]),
                       Point(o["center"][0], o["center"][1], o["center"][2]),
                       o["radius"])
        elif o["type"] == "plane":
            obj = Plane(o["reflectivity"],
                        Color(o["color"][0], o["color"][1], o["color"][2]),
                        Point(o["point"][0], o["point"][1], o["point"][2]),
                        Vector(o["normal"][0], o["normal"][1], o["normal"][2]))
            if o["checkerboard"]:
                obj.color2 = Color(o["color2"][0],
                                   o["color2"][1],
                                   o["color2"][2])
                obj.orientation = Vector(o["orientation"][0],
                                         o["orientation"][1],
                                         o["orientation"][2])
        else:
            raise RuntimeError("Unknown object type: " + o["type"])
        scene.add_object(obj)
    return scene


def in_shadow(scene: Scene, point: Point) -> bool:
    return scene.nearest_intersection(point, scene.light - point) is not None


def color_ray(scene: Scene, start: Point, direction: Vector,
              refls: int) -> Color:
    res = scene.nearest_intersection(start, direction)
    if res is None:
        return scene.background
    (t, obj) = res
    collision = start + t * direction
    reflectivity = obj.reflectivity
    amb = scene.ambient * (1 - reflectivity)
    lighting = amb * obj.get_color(collision)
    norm = obj.get_normal_vector(collision).normalize()
    if not in_shadow(scene, collision + 1e-6 * norm):
        light_direction = (scene.light - collision).normalize()
        lighting += (1 - amb) * (1 - reflectivity) * \
            max(0, norm.dot_product(light_direction)) * \
            obj.get_color(collision)
        half = (light_direction + (-direction).normalize()).normalize()
        lighting += scene.specular * \
            max(0, half.dot_product(norm)) ** scene.specular_power * \
            Color(255, 255, 255)
    if refls < scene.max_reflections and obj.reflectivity > 0.003:
        op = -direction.normalize()
        ref = op + 2 * (op.project(norm) - op)
        lighting += (1 - amb) * reflectivity * \
            color_ray(scene, collision + 1e-6 * ref, ref, refls + 1)
    return lighting


def color_point(scene: Scene, point: Point) -> Color:
    return color_ray(scene, point, point - scene.camera, 0)


def color_pixel(scene: Scene, i: int, j: int) -> Color:
    c = Color(0, 0, 0)
    for _ in range(scene.antialias):
        x = (i + random.random()) / scene.pixel_width
        z = 1 - (j + random.random()) / scene.pixel_width
        c += color_point(scene, Point(x, 0, z))
    return 1 / scene.antialias * c


def main():
    if len(sys.argv) != 3:
        print("Usage: python main.py <config-file> <output-file>")
        sys.exit(0)
    scene = parse_scene(sys.argv[1])
    img = Image.new("RGB", (scene.pixel_width, scene.pixel_height))
    for i in range(scene.pixel_width):
        for j in range(scene.pixel_height):
            c = color_pixel(scene, i, j)
            r = max(0, min(255, int(c.red)))
            g = max(0, min(255, int(c.green)))
            b = max(0, min(255, int(c.blue)))
            img.putpixel((i, j), (r, g, b))
    img.save(sys.argv[2])


if __name__ == "__main__":
    main()
