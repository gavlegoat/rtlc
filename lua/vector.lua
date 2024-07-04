Vector = {}
Vector.mt = {}

function Vector.new (vec)
    setmetatable(vec, Vector.mt)
    return vec
end

function Vector.vop (f, ...)
    local vec = {}
    for i = 1, 3 do
        local fargs = {}
        for j, v in ipairs{...} do
            fargs[j] = v[i]
        end
        vec[i] = f(table.unpack(fargs))
    end
    return Vector.new(vec)
end

Vector.mt.__add = function (u, v)
    return Vector.vop(function (x, y) return x + y end, u, v)
end

Vector.mt.__sub = function (u, v)
    return Vector.vop(function (x, y) return x - y end, u, v)
end

Vector.mt.__mul = function (c, v)
    return Vector.vop(function (x) return c * x end, v)
end

Vector.mt.__unm = function (v)
    return Vector.vop(function (x) return -x end, v)
end

function Vector.dot (u, v)
    local w = Vector.vop(function (x, y) return x * y end, u, v)
    local total = 0
    for i = 1, 3 do
        total = total + w[i]
    end
    return total
end

function Vector.magnitude (v)
    return math.sqrt(Vector.dot(v, v))
end

function Vector.normalize (v)
    return 1 / Vector.magnitude(v) * v
end

function Vector.project (u, v)
    return Vector.dot(u, v) / Vector.dot(v, v) * v
end
