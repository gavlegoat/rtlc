#pragma once

#include <cmath>

class Vector {
public:
    double x;
    double y;
    double z;

    Vector(double, double, double);

    double dot_product(Vector) const;
    Vector cross_product(Vector) const;
    double magnitude() const;
    Vector project(Vector) const;
    Vector operator-(Vector) const;
    Vector operator-() const;
    Vector operator+(Vector) const;

    friend Vector operator*(double, Vector);
};

class Point {
public:
    double x;
    double y;
    double z;

    Point(double, double, double);

    Vector operator-(Point) const;
    Point operator+(Vector) const;

};

class Ray {
public:
    Point start;
    Vector direction;

    Ray(Point, Vector);
};

class Color {
public:
    double red;
    double green;
    double blue;

    Color();
    Color(double, double, double);

    Color operator+(Color);
    Color& operator+=(Color);

    friend Color operator*(double, Color);
};

