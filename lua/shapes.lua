Shape = {}

function Shape:new (o)
    setmetatable(o, self)
    self.__index = self
    return o
end

Sphere = Shape:new{}

function Sphere:colorat (pt)
    return self.color
end

function Sphere:normalat (pt)
    return pt - self.center
end

function Sphere:collisiontime (pt, dir)
    local a = Vector.dot(dir, dir)
    local v = pt - self.center
    local b = 2 * Vector.dot(dir, v)
    local c = Vector.dot(v, v) - self.radius * self.radius
    local discr = b * b - 4 * a * c
    if discr < 0 then
        return nil
    end
    local t1 = (-b + math.sqrt(discr)) / (2 * a)
    local t2 = (-b - math.sqrt(discr)) / (2 * a)
    if t1 < 0 then
        if t2 < 0 then
            return nil
        end
        return t2
    end
    if t2 < 0 then
        return t1
    end
    return math.min(t1, t2)
end

Plane = Shape:new{}

function Plane:colorat (pt)
    if not self.checkerboard then
        return self.color
    end
    local v = pt - self.point
    local x = Vector.project(v, self.orientation)
    local y = v - x
    local ix = math.floor(Vector.magnitude(x) + 0.5)
    local iy = math.floor(Vector.magnitude(y) + 0.5)
    if (ix + iy) % 2 == 0 then
        return self.color
    end
    return self.check_color
end

function Plane:normalat (pt)
    return self.normal
end

function Plane:collisiontime (pt, dir)
    local angle = Vector.dot(self.normal, dir)
    if math.abs(angle) < 1e-6 then
        return nil
    end
    local t = Vector.dot(self.normal, self.point - pt) / angle
    if t < 0 then
        return nil
    end
    return t
end
