#pragma once

typedef struct {
    double x, y, z;
} vector;

typedef struct {
    double x, y, z;
} point;

typedef struct {
    double r, g, b;
} color;

vector v_add(vector, vector);
vector v_mul(double, vector);
vector v_sub(vector, vector);
vector v_neg(vector);
vector p_sub(point, point);
point p_add(point, vector);
double dot_product(vector, vector);
double magnitude(vector);
vector project(vector, vector);
color c_add(color, color);
color c_mul(double, color);
