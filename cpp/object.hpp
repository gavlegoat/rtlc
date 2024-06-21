#pragma once

#include <optional>

#include "types.hpp"

/**
 * Objects are the shapes that make up a scene.
 *
 * All objects are 3-dimensional. They may or may not be translucent, reflective 
 */
class Object {
protected:
    double reflectivity;
    Color color;

public:
    Object(double, Color);

    virtual ~Object() {}

    /** Given a ray, find the time index at which that ray intersects this object
      first. Returns nothing if the ray does not intersect this object. */
    virtual std::optional<double> collision(Ray) const = 0;

    /** Find a normal vector to this object at the given point. The point is
      assumed to lie on the object's surface. */
    virtual Vector normal(Point) const = 0;

    /** Get the color of this object at the given point. The point is assumed to
      lie on the object's surface. */
    virtual Color get_color(Point) const;

    virtual double get_reflectivity(Point) const {
        return this->reflectivity;
    }

};

/**
 * A sphere of solid material, as defined by a center and a radius.
 */
class Sphere: public Object {
private:
    Point center;
    double radius;

public:
    Sphere(double, Color, Point, double);
    std::optional<double> collision(Ray) const override;
    Vector normal(Point) const override;
};

/**
 * A plane extends infinitely in two dimensions. In contrast to mathematical
 * planes, our planes have thickness since every object must be 3D. Planes may
 * optionally be colored with a checkerboard pattern. In this case the squares
 * are centered on point1 and always have size 1.
 */
class Plane: public Object {
private:
    Vector norm;
    Point point;
    std::optional<Color> checkerboard;
    std::optional<Vector> orientation;

public:
    Plane(double, Color, Vector, Point);
    Plane(double, Color, Vector, Point, Color, Vector);

    std::optional<double> collision(Ray) const override;
    Vector normal(Point) const override;
    Color get_color(Point) const override;
};
