#include "types.hpp"

Vector::Vector(double x, double y, double z): x{x}, y{y}, z{z} {}

double Vector::dot_product(Vector other) const {
    return this->x * other.x + this->y * other.y + this->z * other.z;
}

Vector Vector::cross_product(Vector other) const {
    return Vector(this->y * other.z - this->z * other.y,
                  this->z * other.x - this->x * other.z,
                  this->x * other.y - this->y * other.x);
}

double Vector::magnitude() const {
    return std::sqrt(this->dot_product(*this));
}

Vector Vector::project(Vector other) const {
    return (this->dot_product(other) / other.dot_product(other)) * other;
}

Vector Vector::operator-(Vector other) const {
    return Vector(this->x - other.x, this->y - other.y, this->z - other.z);
}

Vector Vector::operator-() const {
    return Vector(-this->x, -this->y, -this->z);
}

Vector Vector::operator+(Vector other) const {
    return Vector(this->x + other.x, this->y + other.y, this->z + other.z);
}

Vector operator*(double a, Vector v) {
    return Vector(a * v.x, a * v.y, a * v.z);
}

Point::Point(double x, double y, double z): x{x}, y{y}, z{z} {}

Vector Point::operator-(Point other) const {
    return Vector(this->x - other.x, this->y - other.y, this->z - other.z);
}

Point Point::operator+(Vector other) const {
    return Point(this->x + other.x, this->y + other.y, this->z + other.z);
}

Ray::Ray(Point p, Vector v): start{p}, direction{v} {}

Color::Color(): red{0.0}, green{0.0}, blue{0.0} {}

Color::Color(double r, double g, double b): red{r}, green{g}, blue{b} {}

Color Color::operator+(Color other) {
    return Color(this->red + other.red,
                 this->green + other.green,
                 this->blue + other.blue);
}

Color& Color::operator+=(Color other) {
    this->red += other.red;
    this->green += other.green;
    this->blue += other.blue;
    return *this;
}

Color operator*(double a, Color c) {
    return Color(a * c.red, a * c.green, a * c.blue);
}
