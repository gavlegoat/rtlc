#pragma once

#include <vector>

#include "object.hpp"
#include "types.hpp"
#include "json.hpp"

class Scene {
private:
    std::vector<std::unique_ptr<Object>> objects;
    Color compute_ray_color(Ray, unsigned int);

public:
    Point camera;
    Point light;
    double ambient;
    double specular;
    int specular_power;
    double limit;
    unsigned int max_reflections;
    bool depth_of_field;
    Color background;
    size_t pixel_width;
    size_t pixel_height;
    size_t antialias;

    Scene(Point);
    Scene(Point, Point, double, double, bool, Color);
    Scene(std::string);
    void add_object(std::unique_ptr<Object>&&);
    std::optional<std::pair<std::reference_wrapper<Object>, double> > get_intersection(Ray);
    Color compute_point_color(Point);
    Color compute_pixel_color(size_t, size_t);
};
