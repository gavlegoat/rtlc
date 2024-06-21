#include <fstream>
#include <random>

#include "json.hpp"
#include "scene.hpp"

using json = nlohmann::json;

Scene::Scene(Point c):
    objects{},
    camera{c},
    light{Point(0, 0, 0)},
    ambient{0.2},
    specular{0.5},
    specular_power{8},
    limit{10.0},
    max_reflections{6},
    depth_of_field{false},
    background{Color(135, 206, 235)},
    pixel_width{512},
    pixel_height{512},
    antialias{1}
{}

Scene::Scene(Point c, Point lig, double a, double l, bool dof, Color bg):
    objects{},
    camera{c},
    light{lig},
    ambient{a},
    specular{0.5},
    specular_power{8},
    limit{l},
    max_reflections{6},
    depth_of_field{dof},
    background{bg},
    pixel_width{512},
    pixel_height{512},
    antialias{1}
{}

std::unique_ptr<Object> parse_object(json obj) {
    double refl = obj["reflectivity"];
    Color col(obj["color"][0], obj["color"][1], obj["color"][2]);
    if (obj["type"] == "sphere") {
        Point center(obj["center"][0],
                     obj["center"][1],
                     obj["center"][2]);
        double rad = obj["radius"];
        return std::make_unique<Sphere>(refl, col, center, rad);
    } else if (obj["type"] == "plane") {
        Vector norm(obj["normal"][0],
                    obj["normal"][1],
                    obj["normal"][2]);
        Point point(obj["point"][0],
                    obj["point"][1],
                    obj["point"][2]);
        if (obj["checkerboard"]) {
            Color col2(obj["color2"][0], obj["color2"][1], obj["color2"][2]);
            Vector orientation(obj["orientation"][0], obj["orientation"][1],
                               obj["orientation"][2]);
            return std::make_unique<Plane>(refl, col, norm, point, col2, orientation);
        } else {
            return std::make_unique<Plane>(refl, col, norm, point);
        }
    } else {
        throw std::invalid_argument("Unknown object type: " +
                                    obj["type"].get<std::string>());
    }
}

Scene::Scene(std::string filename):
    objects{},
    camera{Point(0, 0, 0)},
    light{Point(0, 0, 0)},
    ambient{0.2},
    specular{0.5},
    specular_power{8},
    limit{10.0},
    max_reflections{6},
    depth_of_field{false},
    background{Color(135, 206, 235)},
    pixel_width{512},
    pixel_height{512},
    antialias{1}
{
    std::ifstream infile(filename);
    json data = json::parse(infile);
    this->camera = Point(data["camera"][0], data["camera"][1], data["camera"][2]);
    this->light = Point(data["light"][0], data["light"][1], data["light"][2]);
    this->antialias = data["antialias"];
    for (json obj : data["objects"]) {
        this->add_object(parse_object(obj));
    }
}

void Scene::add_object(std::unique_ptr<Object>&& obj) {
    this->objects.push_back(std::move(obj));
}

std::optional<std::pair<std::reference_wrapper<Object>, double>> Scene::get_intersection(Ray r) {
    std::optional<std::pair<std::reference_wrapper<Object>, double>> nearest;
    for (const std::unique_ptr<Object>& o : this->objects) {
        auto t = o->collision(r);
        if (t && (!nearest || *t < nearest->second)) {
            nearest =
                std::optional(std::make_pair<std::reference_wrapper<Object>, double>(*o, std::move(*t)));
        }
    }
    return nearest;
}

Color Scene::compute_ray_color(Ray ray, unsigned int reflections) {
    auto res = this->get_intersection(ray);
    if (!res) {
        return background;
    }
    const Object& obj = res->first;
    double time = res->second;
    Point collision = ray.start + time * ray.direction;

    // Ambient light
    Color c = obj.get_color(collision);
    double reflect = obj.get_reflectivity(collision);
    double amb = this->ambient * (1 - reflect);
    Color l_amb = amb * c;
    Color lighting = l_amb;

    // Diffuse light
    Vector light_dir = this->light - collision;
    // Check if we're in a shadow
    if (!get_intersection(Ray(collision + 1e-5 * light_dir, light_dir))) {
        light_dir = 1 / light_dir.magnitude() * light_dir;
        Vector norm = obj.normal(collision);
        norm = 1 / norm.magnitude() * norm;
        Color l_diff =
            (1 - amb) * (1 - reflect) * std::max(0.0, norm.dot_product(light_dir)) * c;
        lighting += l_diff;

        // Specular light
        Vector v = 1 / (ray.direction.magnitude()) * (-ray.direction);
        Vector half = v + light_dir;
        half = 1 / half.magnitude() * half;
        Color l_spec =
            this->specular *
            std::pow(std::max(0.0, half.dot_product(norm)), this->specular_power) *
            Color(255, 255, 255);
        lighting += l_spec;
    }

    if (reflections < max_reflections && obj.get_reflectivity(collision) > 0.003) {
        Vector v = 1 / ray.direction.magnitude() * (-ray.direction);
        Vector diff = v.project(obj.normal(collision)) - v;
        Vector refl = v + 2 * diff;
        Color reflected =
            this->compute_ray_color(Ray(collision + 1e-5 * refl, refl),
                                    reflections + 1);
        lighting += (1 - amb) * reflect * reflected;
    }
    return lighting;
}

Color Scene::compute_point_color(Point p) {
    return this->compute_ray_color(Ray(p, p - camera), 0);
}

Color Scene::compute_pixel_color(size_t i, size_t j) {
    double x_min = ((double) i) / this->pixel_width;
    double z_min = 1 - ((double) j) / this->pixel_width;
    double size = 1.0 / this->pixel_width;
    std::random_device dev;
    std::mt19937 rng(dev());
    std::uniform_real_distribution<double> distr(0.0, size);

    Color c(0, 0, 0);
    for (size_t k = 0; k < this->antialias; k++) {
        double x = x_min + distr(rng);
        double z = z_min + distr(rng);
        c += this->compute_point_color(Point(x, 0, z));
    }
    return (1.0 / this->antialias) * c;
}
