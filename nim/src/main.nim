import std/options
import std/random
import std/math
import std/json
import std/os
import nimPNG

import shapes
import vector

type Scene = object
    ambient: float
    specular: float
    specularPower: float
    maxRefls: int
    light: Point
    camera: Point
    background: Color
    objects: seq[Shape]

proc nearestIntersection(scene: Scene, pt: Point, dir: Vector): Option[(float, Shape)] =
    for obj in scene.objects:
        let t = obj.collision(pt, dir)
        if t.isSome and (result.isNone or t.get < result.get[0]):
            result = some((t.get, obj))

proc inShadow(scene: Scene, pt: Point): bool =
    let dir = scene.light - pt
    nearestIntersection(scene, pt + 1e-6 * dir, dir).isSome

proc colorRay(scene: Scene, pt: Point, dir: Vector, refls: int): Color =
    let res = nearestIntersection(scene, pt, dir)
    if res.isNone:
        return scene.background
    let (t, obj) = res.get
    let col = pt + t * dir
    let refl = obj.reflectivity
    let amb = scene.ambient * (1 - refl)
    let color = obj.color(col)
    var lighting = amb * color
    let norm = normalize(obj.normal(col))
    let op = normalize(-dir)
    if not inShadow(scene, col):
        let lightDir = normalize(scene.light - col)
        lighting += (1 - amb) * (1 - refl) * max(0, dot(norm, lightDir)) * color
        let half = normalize(lightDir + op)
        lighting += scene.specular *
            pow(max(0, dot(half, norm)), scene.specularPower) *
            [255.0, 255.0, 255.0]
    if refls < scene.maxRefls and refl > 0.003:
        let refDir = op + 2 * (project(op, norm) - op)
        lighting += (1 - amb) * refl *
            colorRay(scene, col + 1e-6 * refDir, refDir, refls + 1)
    return lighting

proc colorPoint(scene: Scene, pt: Point): Color =
    return scene.colorRay(pt, pt - scene.camera, 0)

proc colorPixel(scene: Scene, x, y, scale, antialias: int): Color =
    var color: Color = [0, 0, 0]
    for i in 1..antialias:
        let rx = (rand(1.0) + x.float) / scale.float
        let ry = 1.0 - (rand(1.0) + y.float) / scale.float
        color += colorPoint(scene, [rx, 0, ry])
    return 1.0 / antialias.float * color

func intoVector(data: JsonNode): Vector =
    for i in 0..2: result[i] = data[i].getFloat

proc parseScene(filename: string): (Scene, int) =
    let jsonString = readFile(filename)
    let json = parseJson(jsonString)
    let antialias = json["antialias"].getInt
    let light = intoVector(json["light"])
    let camera = intoVector(json["camera"])
    var objs: seq[Shape]
    for o in json["objects"]:
        let refl = o["reflectivity"].getFloat
        let color = intoVector(o["color"])
        if o["type"].getStr == "sphere":
            objs.add(mkSphere(refl, color, intoVector(o["center"]),
                              o["radius"].getFloat))
        else:
            if o["checkerboard"].getBool:
                objs.add(mkPlane(refl,
                                 color,
                                 intoVector(o["point"]),
                                 intoVector(o["normal"]),
                                 intoVector(o["color2"]),
                                 intoVector(o["orientation"])))
            else:
                objs.add(mkPlane(refl,
                                 color,
                                 intoVector(o["point"]),
                                 intoVector(o["normal"])))
    let scene = Scene(ambient : 0.2,
                      specular : 0.5,
                      specularPower : 8,
                      maxRefls : 6,
                      light : light,
                      camera : camera,
                      background : [135.0, 206.0, 235.0],
                      objects : objs)
    return (scene, antialias)

when isMainModule:
    if paramCount() != 2:
        echo "Usage: main <config-file> <output-file>"
        quit(1)
    let (scene, antialias) = parseScene(paramStr(1))
    let width = 512
    let height = 512
    var img = newSeq[uint8](width * height * 3)
    for i in 0..height-1:
        for j in 0..width-1:
            let color = colorPixel(scene, j, i, width, antialias)
            img[3*width*i + 3*j + 0] = min(255, max(0, (color[0] + 0.5).int)).uint8
            img[3*width*i + 3*j + 1] = min(255, max(0, (color[1] + 0.5).int)).uint8
            img[3*width*i + 3*j + 2] = min(255, max(0, (color[2] + 0.5).int)).uint8
    let res = savePNG24(paramStr(2), img, width, height)
