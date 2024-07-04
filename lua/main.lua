require 'vector'
require 'shapes'

function nearestintersection (scene, pt, dir)
    local mintime = nil
    local bestobj = nil
    for _, obj in ipairs(scene.objects) do
        local t = obj:collisiontime(pt, dir)
        if t and (not mintime or t < mintime) then
            mintime = t
            bestobj = obj
        end
    end
    return mintime, bestobj
end

function inshadow (scene, pt)
    local dir = scene.light - pt
    local pt = pt + 1e-6 * dir
    local t, _ = nearestintersection(scene, pt, dir)
    return t
end

function colorray (scene, pt, dir, refls)
    local t, obj = nearestintersection(scene, pt, dir)
    if not t then
        return scene.background
    end
    local col = pt + t * dir
    local amb = scene.ambient * (1 - obj.reflectivity)
    local color = obj:colorat(col)
    local lighting = amb * color
    local norm = Vector.normalize(obj:normalat(col))
    local op = Vector.normalize(-dir)
    if not inshadow(scene, col) then
        local lightdir = Vector.normalize(scene.light - col)
        local factor = (1 - amb) * (1 - obj.reflectivity) * math.max(0, Vector.dot(norm, lightdir))
        lighting = lighting + factor * color
        local half = Vector.normalize(lightdir + op)
        factor = math.max(0, Vector.dot(norm, half)) ^ scene.specularpower
        factor = factor * scene.specular
        lighting = lighting + factor * Vector.new{255, 255, 255}
    end
    if refls < scene.maxrefls and obj.reflectivity > 0.003 then
        local ref = op + 2 * (Vector.project(op, norm) - op)
        local factor = (1 - amb) * obj.reflectivity
        color = colorray(scene, col + 1e-6 * ref, ref, refls + 1)
        lighting = lighting + factor * color
    end
    return lighting
end

function colorpoint (scene, pt)
    return colorray(scene, pt, pt - scene.camera, 0)
end

function colorpixel (scene, x, y, scale, antialias)
    local color = Vector.new{0, 0, 0}
    for i = 1, antialias do
        local rx = (x + math.random()) / scale
        local ry = 1 - (y + math.random()) / scale
        color = color + colorpoint(scene, Vector.new{rx, 0, ry})
    end
    return 1.0 / antialias * color
end

function parsescene (filename)
    local file = io.open(filename, 'r')
    local contents = file:read("*all")
    file:close()
    local json = require 'json'
    local data = json.parse(contents)
    local scene = {}
    scene.ambient = 0.2
    scene.specular = 0.5
    scene.specularpower = 8
    scene.maxrefls = 6
    scene.background = Vector.new{135, 206, 235}
    scene.light = Vector.new(data.light)
    scene.camera = Vector.new(data.camera)
    scene.objects = {}
    for _, obj in ipairs(data.objects) do
        obj.color = Vector.new(obj.color)
        if obj.type == 'sphere' then
            obj.center = Vector.new(obj.center)
            table.insert(scene.objects, Sphere:new(obj))
        else
            obj.point = Vector.new(obj.point)
            obj.normal = Vector.new(obj.normal)
            if obj.checkerboard then
                obj.check_color = Vector.new(obj.color2)
                obj.orientation = Vector.new(obj.orientation)
                obj.color2 = nil
            end
            table.insert(scene.objects, Plane:new(obj))
        end
    end
    return scene, data.antialias
end

Img = {}
Img.__index = Img

function Img:write(data)
    table.insert(self.output, string.char(data[1]))
    table.insert(self.output, string.char(data[2]))
    table.insert(self.output, string.char(data[3]))
end

function createimage(width, height)
    local o = {}
    setmetatable(o, Img)
    o.width = width
    o.height = height
    o.output = {'P6\n', tostring(width), ' ', tostring(height), '\n255\n'}
    return o
end

function main (configfile, outputfile)
    local scene, antialias = parsescene(configfile)
    local width = 512
    local height = 512
    local img = createimage(width, height)
    for i = 1, height do
        print(i)
        for j = 1, width do
            local color = colorpixel(scene, j-1, i-1, width, antialias)
            color = Vector.vop(function (x)
                return math.min(255, math.max(0, math.floor(x + 0.5)))
            end, color)
            img:write(color)
        end
    end
    local data = img.output
    local file = io.open(outputfile, "wb")
    file:write(table.concat(data))
    file:close()
end

main(arg[1], arg[2])
