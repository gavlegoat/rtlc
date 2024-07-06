const vec = @import("vector.zig");

const Sphere = struct {
    center: @Vector(3, f64),
    radius: f64,
};

const Plane = struct {
    point: @Vector(3, f64),
    normal: @Vector(3, f64),
    check_color: ?@Vector(3, f64),
    orientation: ?@Vector(3, f64),
};

const ShapeType = enum { sphere, plane };

const ShapeUnion = union(ShapeType) { sphere: Sphere, plane: Plane };

pub const Shape = struct {
    reflectivity: f64,
    color: @Vector(3, f64),
    shape: ShapeUnion,
};

pub fn mkSphere(refl: f64, color: @Vector(3, f64), center: @Vector(3, f64), radius: f64) Shape {
    return Shape{
        .reflectivity = refl,
        .color = color,
        .shape = ShapeUnion{ .sphere = Sphere{
            .center = center,
            .radius = radius,
        } },
    };
}

pub fn mkPlane(refl: f64, color: @Vector(3, f64), point: @Vector(3, f64), normal: @Vector(3, f64)) Shape {
    return Shape{
        .reflectivity = refl,
        .color = color,
        .shape = ShapeUnion{
            .plane = Plane{
                .point = point,
                .normal = normal,
                .check_color = null,
                .orientation = null,
            },
        },
    };
}

pub fn mkCheckedPlane(refl: f64, color: @Vector(3, f64), point: @Vector(3, f64), normal: @Vector(3, f64), check_color: @Vector(3, f64), ori: @Vector(3, f64)) Shape {
    return Shape{
        .reflectivity = refl,
        .color = color,
        .shape = ShapeUnion{
            .plane = Plane{
                .point = point,
                .normal = normal,
                .check_color = check_color,
                .orientation = ori,
            },
        },
    };
}

fn getPlaneColor(pl: *Plane, col: @Vector(3, f64), pt: @Vector(3, f64)) @Vector(3, f64) {
    if (pl.check_color) |col2| {
        const v = pt - pl.point;
        const x = vec.project(v, pl.orientation.?);
        const y = v - x;
        const ix: i64 = @intFromFloat(vec.magnitude(x) + 0.5);
        const iy: i64 = @intFromFloat(vec.magnitude(y) + 0.5);
        if (@mod(ix + iy, 2) == 0) {
            return col;
        }
        return col2;
    }
    return col;
}

pub fn getColor(sh: *Shape, pt: @Vector(3, f64)) @Vector(3, f64) {
    switch (sh.shape) {
        .sphere => return sh.color,
        .plane => |*pl| return getPlaneColor(pl, sh.color, pt),
    }
}

pub fn getNormal(sh: *Shape, pt: @Vector(3, f64)) @Vector(3, f64) {
    switch (sh.shape) {
        .sphere => |*sph| return pt - sph.center,
        .plane => |*pl| return pl.normal,
    }
}

fn getSphereColTime(sph: *Sphere, pt: @Vector(3, f64), dir: @Vector(3, f64)) ?f64 {
    const a = vec.dot(dir, dir);
    const v = pt - sph.center;
    const b = 2 * vec.dot(dir, v);
    const c = vec.dot(v, v) - sph.radius * sph.radius;
    const discr = b * b - 4 * a * c;
    if (discr < 0) {
        return null;
    }
    const t1 = (-b + @sqrt(discr)) / (2 * a);
    const t2 = (-b - @sqrt(discr)) / (2 * a);
    if (t1 < 0) {
        if (t2 < 0) {
            return null;
        }
        return t2;
    }
    if (t2 < 0) {
        return null;
    }
    return @min(t1, t2);
}

fn getPlaneColTime(pl: *Plane, pt: @Vector(3, f64), dir: @Vector(3, f64)) ?f64 {
    const angle = vec.dot(pl.normal, dir);
    if (@abs(angle) < 1e-6) {
        return null;
    }
    const t = vec.dot(pl.normal, pl.point - pt) / angle;
    if (t < 0) {
        return null;
    }
    return t;
}

pub fn getCollisionTime(sh: *Shape, pt: @Vector(3, f64), dir: @Vector(3, f64)) ?f64 {
    switch (sh.shape) {
        .sphere => |*sph| return getSphereColTime(sph, pt, dir),
        .plane => |*pl| return getPlaneColTime(pl, pt, dir),
    }
}
