#include "object.hpp"

Object::Object(double refl, Color c):
    reflectivity{refl},
    color{c}
{}

Color Object::get_color([[maybe_unused]] Point p) const {
    return this->color;
}

Sphere::Sphere(double refl, Color col, Point c, double rad):
    Object(refl, col),
    center{c},
    radius{rad}
{}

std::optional<double> Sphere::collision(Ray r) const {
    // Surface of the sphere: points s satisfying || c - s || = r
    // Looking for a time t for which || c - (p + t v) || = r
    // So: || c - (p + t v) || = r
    //     || c - (p + t v) ||^2 = r^2
    //     (c - (p + t v)) . (c - (p + t v)) = r^2
    //     c . c + (p + t v) . (p + t v) - 2 c . (p + t v) = r^2
    //     c . c + p . p + 2 p . t v + t v . t v - 2 c . p - 2 c . t v = r^2
    //     t^2 (v . v) + 2 t (p . v - c . v) + (c . c + p . p - 2 c . p) = r^2
    //     t^2 (v . v) + 2 t ((p - c) . v) + (c - p) . (c - p) = r^2
    //     let a = v . v, b = 2 (p - c) . v, and c = (c - p) . (c - p) - r^2
    //     Then by quadratic formula:
    //     t = (-b +/- sqrt(b^2 - 4 a c)) / (2 a)
    Point p = r.start;
    Vector v = r.direction;
    double a = v.dot_product(v);
    double b = 2 * (p - this->center).dot_product(v);
    double c = (this->center - p).dot_product(this->center - p) -
        this->radius * this->radius;
    double discr = b * b - 4 * a * c;
    if (discr < 0) {
        return {};
    }
    double t1 = (-b + std::sqrt(discr)) / (2 * a);
    double t2 = (-b - std::sqrt(discr)) / (2 * a);
    if (t1 < 0) {
        if (t2 < 0) {
            return {};
        } else {
            return t2;
        }
    } else if (t2 < 0) {
        return t1;
    } else {
        return std::min(t1, t2);
    }
}

Vector Sphere::normal(Point p) const {
    return p - this->center;
}

Plane::Plane(double refl, Color c, Vector n, Point p):
    Object(refl, c),
    norm{n},
    point{p},
    checkerboard{},
    orientation{}
{}

Plane::Plane(double refl, Color c, Vector n, Point p, Color c2, Vector ori):
    Object(refl, c),
    norm{n},
    point{p},
    checkerboard{c2},
    orientation{ori}
{}

std::optional<double> Plane::collision(Ray r) const {
    // A plane is defined by (s - c) . n = 0 (for c = point, n = norm)
    // We want ((p + t v) - c) . n = 0
    //         (p - c + t v) . n = 0
    //         p . n - c . n + t (v . n) = 0
    //         t = (c . n - p . n) / (v . n) = ((c - p) . n) / (v . n)
    Point p = r.start;
    Vector v = r.direction;
    if (std::abs(v.dot_product(this->norm)) < 1e-6) {
        // The ray is (nearly) parallel to the plane
        return {};
    }
    double t = (this->point - p).dot_product(this->norm) /
        v.dot_product(this->norm);
    if (t < 0) {
        return {};
    } else {
        return t;
    }
}

Vector Plane::normal([[maybe_unused]] Point p) const {
    return this->norm;
}

Color Plane::get_color(Point p) const {
    if (!this->checkerboard) {
        return this->color;
    }
    Vector v = p - this->point;
    Vector x =
        (v.dot_product(*this->orientation) /
        (orientation->dot_product(*this->orientation))) *
        *this->orientation;
    Vector y = v - x;
    int ix = (int) (x.magnitude() + 0.5);
    int iy = (int) (y.magnitude() + 0.5);
    if ((ix + iy) % 2 == 0) {
        return this->color;
    } else {
        return *this->checkerboard;
    }
}
