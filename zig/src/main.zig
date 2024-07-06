const std = @import("std");
const vec = @import("vector.zig");
const shapes = @import("shapes.zig");
const image = @import("zigimg");

const Scene = struct {
    ambient: f64,
    specular: f64,
    specular_power: f64,
    max_refls: usize,
    light: @Vector(3, f64),
    camera: @Vector(3, f64),
    background: @Vector(3, f64),
    objects: []*shapes.Shape,
    objsLen: usize,

    pub fn deinit(self: *Scene, alloc: std.mem.Allocator) void {
        for (0..self.objsLen) |i| {
            alloc.destroy(self.objects[i]);
        }
        alloc.free(self.objects);
    }
};

const Intersection = struct {
    time: f64,
    object: *shapes.Shape,
};

fn nearestIntersection(scene: *const Scene, pt: @Vector(3, f64), dir: @Vector(3, f64)) ?Intersection {
    var mintime: ?f64 = null;
    var bestobj: ?*shapes.Shape = null;
    for (scene.objects) |obj| {
        if (shapes.getCollisionTime(obj, pt, dir)) |t| {
            if (mintime) |mt| {
                if (t < mt) {
                    mintime = t;
                    bestobj = obj;
                }
            } else {
                mintime = t;
                bestobj = obj;
            }
        }
    }
    if (mintime) |mt| {
        return Intersection{
            .time = mt,
            .object = bestobj.?,
        };
    }
    return null;
}

fn inShadow(scene: *const Scene, pt: @Vector(3, f64)) bool {
    const dir = scene.light - pt;
    return nearestIntersection(scene, pt, dir) != null;
}

fn offset(pt: @Vector(3, f64), dir: @Vector(3, f64)) @Vector(3, f64) {
    return pt + @as(@Vector(3, f64), @splat(1e-6)) * dir;
}

fn getRayColor(scene: *const Scene, pt: @Vector(3, f64), dir: @Vector(3, f64), refls: usize) @Vector(3, f64) {
    if (nearestIntersection(scene, pt, dir)) |int| {
        const col = pt + @as(@Vector(3, f64), @splat(int.time)) * dir;
        const refl = int.object.reflectivity;
        const amb = scene.ambient * (1 - refl);
        const color = shapes.getColor(int.object, col);
        var lighting = @as(@Vector(3, f64), @splat(amb)) * color;
        const norm = vec.normalize(shapes.getNormal(int.object, col));
        const op = vec.normalize(-dir);
        if (!inShadow(scene, offset(col, norm))) {
            const lightDir = vec.normalize(scene.light - col);
            var f = (1 - amb) * (1 - refl) * @max(0, vec.dot(norm, lightDir));
            lighting += @as(@Vector(3, f64), @splat(f)) * color;
            const half = vec.normalize(lightDir + op);
            f = scene.specular * std.math.pow(f64, @max(0, vec.dot(half, norm)), scene.specular_power);
            lighting += @as(@Vector(3, f64), @splat(f)) * @Vector(3, f64){ 255, 255, 255 };
        }
        if (refls < scene.max_refls and refl > 0.003) {
            const ref = op + @as(@Vector(3, f64), @splat(2.0)) * (vec.project(op, norm) - op);
            const f = (1 - amb) * refl;
            const rcol = getRayColor(scene, offset(col, ref), ref, refls + 1);
            lighting += @as(@Vector(3, f64), @splat(f)) * rcol;
        }
        return lighting;
    }
    return scene.background;
}

fn getPointColor(scene: *const Scene, pt: @Vector(3, f64)) @Vector(3, f64) {
    return getRayColor(scene, pt, pt - scene.camera, 0);
}

fn getPixelColor(scene: *const Scene, x: usize, y: usize, scale: usize, antialias: usize, rng: *std.Random.DefaultPrng) @Vector(3, f64) {
    var color = @Vector(3, f64){ 0, 0, 0 };
    for (0..antialias) |_| {
        const rx = (@as(f64, @floatFromInt(x)) + rng.random().float(f64)) / @as(f64, @floatFromInt(scale));
        const ry = 1 - (@as(f64, @floatFromInt(y)) + rng.random().float(f64)) / @as(f64, @floatFromInt(scale));
        color += getPointColor(scene, @Vector(3, f64){ rx, 0.0, ry });
    }
    return @as(@Vector(3, f64), @splat(1.0 / @as(f64, @floatFromInt(antialias)))) * color;
}

fn parseVec(arr: std.json.Array) @Vector(3, f64) {
    var res = @Vector(3, f64){ 0.0, 0.0, 0.0 };
    for (arr.items, 0..3) |n, i| {
        switch (n) {
            .float => |x| res[i] = x,
            .integer => |x| res[i] = @as(f64, @floatFromInt(x)),
            else => undefined,
        }
    }
    return res;
}

fn getErr(map: std.json.ObjectMap, key: []const u8) !std.json.Value {
    if (map.get(key)) |v| {
        return v;
    }
    return undefined;
}

fn parseScene(filename: []const u8, alloc: std.mem.Allocator, antialias: *usize) !Scene {
    const data = try std.fs.cwd().readFileAlloc(alloc, filename, 1000000);
    defer alloc.free(data);
    var parsed: std.json.Parsed(std.json.Value) = try std.json.parseFromSlice(std.json.Value, alloc, data, .{});
    defer parsed.deinit();
    var json: std.json.ObjectMap = parsed.value.object;
    defer json.deinit();
    antialias.* = @intCast((try getErr(json, "antialias")).integer);
    const jsonObjs = (try getErr(json, "objects")).array;
    defer jsonObjs.deinit();
    const objLen = jsonObjs.items.len;
    const objects = try alloc.alloc(*shapes.Shape, objLen);
    for (jsonObjs.items, 0..) |*val, i| {
        var obj = val.object;
        const sh = try alloc.create(shapes.Shape);
        const refl = (try getErr(obj, "reflectivity")).float;
        const color = parseVec((try getErr(obj, "color")).array);
        if (std.mem.eql(u8, (try getErr(obj, "type")).string, "sphere")) {
            const center = parseVec((try getErr(obj, "center")).array);
            const rad = (try getErr(obj, "radius")).float;
            sh.* = shapes.mkSphere(refl, color, center, rad);
        } else {
            const point = parseVec((try getErr(obj, "point")).array);
            const normal = parseVec((try getErr(obj, "normal")).array);
            if ((try getErr(obj, "checkerboard")).bool) {
                const ch_col = parseVec((try getErr(obj, "color2")).array);
                const ori = parseVec((try getErr(obj, "orientation")).array);
                sh.* = shapes.mkCheckedPlane(refl, color, point, normal, ch_col, ori);
            } else {
                sh.* = shapes.mkPlane(refl, color, point, normal);
            }
        }
        objects[i] = sh;
        obj.deinit();
    }
    return Scene{
        .ambient = 0.2,
        .specular = 0.5,
        .specular_power = 8,
        .max_refls = 6,
        .light = parseVec((try getErr(json, "light")).array),
        .camera = parseVec((try getErr(json, "camera")).array),
        .background = @Vector(3, f64){ 135, 206, 235 },
        .objects = objects,
        .objsLen = objLen,
    };
}

fn failWithUsage(comptime T: type) T {
    std.debug.print("Usage: main <config-file> <output-file>\n", .{});
    std.process.exit(1);
    return undefined;
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const config_file = args.next() orelse failWithUsage([]const u8);
    const output_file = args.next() orelse failWithUsage([]const u8);
    if (args.next() != null) {
        failWithUsage(void);
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var antialias: usize = 0;
    var scene: Scene = try parseScene(config_file, alloc, &antialias);
    defer scene.deinit(alloc);

    const width = 512;
    const height = 512;

    var img = try image.Image.create(alloc, width, height, .rgb24);
    defer img.deinit();

    var rng = std.rand.DefaultPrng.init(0);

    for (0..height) |i| {
        for (0..width) |j| {
            const color = getPixelColor(&scene, j, i, width, antialias, &rng);
            img.pixels.rgb24[i * width + j] = .{
                .r = @min(255, @max(0, @as(isize, @intFromFloat(color[0] + 0.5)))),
                .g = @min(255, @max(0, @as(isize, @intFromFloat(color[1] + 0.5)))),
                .b = @min(255, @max(0, @as(isize, @intFromFloat(color[2] + 0.5)))),
            };
        }
    }

    try img.writeToFilePath(output_file, .{ .png = .{} });
}
