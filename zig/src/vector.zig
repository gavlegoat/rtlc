const std = @import("std");

pub fn dot(u: @Vector(3, f64), v: @Vector(3, f64)) f64 {
    return @reduce(.Add, u * v);
}

pub fn magnitude(v: @Vector(3, f64)) f64 {
    return @sqrt(dot(v, v));
}

pub fn normalize(v: @Vector(3, f64)) @Vector(3, f64) {
    return @as(@Vector(3, f64), @splat(1.0 / magnitude(v))) * v;
}

pub fn project(u: @Vector(3, f64), v: @Vector(3, f64)) @Vector(3, f64) {
    return @as(@Vector(3, f64), @splat(dot(u, v) / dot(v, v))) * v;
}

test "vector tests" {
    const u = @Vector(3, f64){ 1.0, 2.0, 3.0 };
    const v = @Vector(3, f64){ 4.0, 5.0, 6.0 };
    try std.testing.expectApproxEqAbs(32.0, dot(u, v), 1e-6);
    try std.testing.expectApproxEqAbs(@sqrt(14.0), magnitude(u), 1e-6);
    const un = normalize(u);
    try std.testing.expectApproxEqAbs(1.0, magnitude(un), 1e-6);
    try std.testing.expectApproxEqAbs(2.0 * un[0], un[1], 1e-6);
    try std.testing.expectApproxEqAbs(3.0 * un[0], un[2], 1e-6);
}
