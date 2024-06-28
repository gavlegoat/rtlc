using JSON
using FileIO
using ColorTypes
using FixedPointNumbers

include("Shapes.jl")

struct Scene
    background :: Color
    light :: Vec
    camera :: Vec
    ambient :: Real
    specular :: Real
    specular_power :: Number
    objects :: Set{Shape}
    maxrefls :: Unsigned
end

function intersection(scene, pt, vec)
    mintime = nothing
    closest = nothing
    for o in scene.objects
        t = getintersection(o, pt, vec)
        if !isnothing(t) && (isnothing(mintime) || t < mintime)
            mintime = t
            closest = o
        end
    end
    return mintime, closest
end

function inshadow(scene, pt)
    dir = scene.light - pt
    pt += dir * 1e-6
    t, _ = intersection(scene, pt, dir)
    !isnothing(t)
end

function raycolor(scene, pt, vec, refls)
    t, o = intersection(scene, pt, vec)
    if isnothing(t)
        return scene.background
    end
    col = pt + t * vec
    refl = o.base.reflectivity
    amb = scene.ambient * (1 - refl)
    color = getcolor(o, col)
    lighting = amb * color
    norm = normalize(getnormal(o, col))
    if !inshadow(scene, col)
        lightdir = normalize(scene.light - col)
        lighting += (1 - amb) * (1 - refl) * max(0, dot(norm, lightdir)) * color
        half = normalize(lightdir - normalize(vec))
        lighting += scene.specular * max(0, dot(half, norm)) ^ scene.specular_power * [255, 255, 255]
    end
    if refls < scene.maxrefls && o.base.reflectivity > 0.003
        op = normalize(-vec)
        ref = op + 2 * (project(op, norm) - op)
        lighting += (1 - amb) * refl * raycolor(scene, col + 1e-6 * ref, ref, refls + 1)
    end
    return lighting
end

function pointcolor(scene, pt)
    raycolor(scene, pt, pt - scene.camera, 0)
end

function pixelcolor(scene, x, y, scale, antialias)
    color = [0, 0, 0]
    for _ in 1:antialias
        rx = (x + rand()) / scale
        ry = 1 - (y + rand()) / scale
        color += pointcolor(scene, [rx, 0, ry])
    end
    color / antialias
end

function parsescene(file)
    json = JSON.parsefile(file)
    scene = Scene([135, 206, 235],
                  json["light"],
                  json["camera"],
                  0.2,
                  0.5,
                  8,
                  Set(),
                  6)
    for o in json["objects"]
        base = ShapeBase(o["color"], o["reflectivity"])
        if o["type"] == "sphere"
            obj = Sphere(base, o["center"], o["radius"])
        elseif o["checkerboard"]
            obj = Plane(base, o["point"], o["normal"], o["color2"], o["orientation"])
        else
            obj = Plane(base, o["point"], o["normal"], nothing, nothing)
        end
        push!(scene.objects, obj)
    end
    return scene, json["antialias"]
end


if length(ARGS) != 2
    print("Usage: julia Main.jl <config-file> <output-file>")
    exit(1)
end

scene, antialias = parsescene(ARGS[1])
width = 512
height = 512
image = Array{RGB{N0f8}, 2}(undef, width, height)
for i in 1:height
    for j in 1:width
        color = map(x->min(255, max(0, x)) / 255, pixelcolor(scene, j, i, width, antialias))
        image[i, j] = RGB(color[1], color[2], color[3])
    end
end
save(ARGS[2], image)
