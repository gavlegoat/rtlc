#include <math.h>

#include "types.h"

vector v_add(vector a, vector b) {
    vector v;
    v.x = a.x + b.x;
    v.y = a.y + b.y;
    v.z = a.z + b.z;
    return v;
}

vector v_mul(double a, vector b) {
    vector v;
    v.x = a * b.x;
    v.y = a * b.y;
    v.z = a * b.z;
    return v;
}

vector v_sub(vector a, vector b) {
    vector v;
    v.x = a.x - b.x;
    v.y = a.y - b.y;
    v.z = a.z - b.z;
    return v;
}

vector v_neg(vector a) {
    vector v;
    v.x = -a.x;
    v.y = -a.y;
    v.z = -a.z;
    return v;
}

vector p_sub(point a, point b) {
    vector v;
    v.x = a.x - b.x;
    v.y = a.y - b.y;
    v.z = a.z - b.z;
    return v;
}

point p_add(point a, vector b) {
    point v;
    v.x = a.x + b.x;
    v.y = a.y + b.y;
    v.z = a.z + b.z;
    return v;
}

double dot_product(vector a, vector b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

double magnitude(vector v) {
    return sqrt(dot_product(v, v));
}

vector project(vector a, vector b) {
    return v_mul(dot_product(a, b) / dot_product(b, b), b);
}

color c_add(color a, color b) {
    color c;
    c.r = a.r + b.r;
    c.g = a.g + b.g;
    c.b = a.b + b.b;
    return c;
}

color c_mul(double a, color b) {
    color c;
    c.r = a * b.r;
    c.g = a * b.g;
    c.b = a * b.b;
    return c;
}
