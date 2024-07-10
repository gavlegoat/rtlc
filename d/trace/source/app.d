import std.stdio;
import std.random;
import std.typecons;
import std.algorithm;
import std.json;
import std.file : readText;
static import png = arsd.png;
import vector;
import shapes;

struct Scene {
    double ambient;
    double specular;
    double specular_power;
    uint max_refls;
    Color background;
    Point light;
    Point camera;
    Shape[] objects;
}

struct Intersection {
    double time;
    Shape* object;
}

Nullable!Intersection nearest_intersection(Scene* scene, Point pt, Vector dir) {
    auto res = Nullable!Intersection.init;
    foreach (ref obj; scene.objects) {
        auto i = obj.get_collision_time(pt, dir);
        if (!i.isNull) {
            if (res.isNull) {
                Intersection tmp = { time : i.get, object : &obj };
                res = tmp.nullable;
            } else if (i.get < res.get.time) {
                res.get.time = i.get;
                res.get.object = &obj;
            }
        }
    }
    return res;
}

bool in_shadow(Scene* scene, Point pt) {
    Vector dir = scene.light[] - pt[];
    auto res = scene.nearest_intersection(pt, dir);
    return !res.isNull;
}

Color color_ray(Scene* scene, Point pt, Vector dir, uint refls) {
    auto res = scene.nearest_intersection(pt, dir);
    if (res.isNull) {
        return scene.background;
    }
    double t = res.get.time;
    Shape* obj = res.get.object;
    Point col = pt[] + t * dir[];
    double refl = obj.get_reflectivity;
    Color color = obj.get_color(col);
    double amb = scene.ambient * (1 - refl);
    Color lighting = amb * color[];
    Vector norm = normalize(obj.get_normal(col));
    Vector op = -dir[];
    op = normalize(op);
    Point tmp = col[] + 1e-6 * norm[];
    if (!scene.in_shadow(tmp)) {
        tmp = scene.light[] - col[];
        Vector lightDir = normalize(tmp);
        lighting[] += (1 - amb) * (1 - refl) * max(0, dot_product(norm, lightDir)) * color[];
        tmp = lightDir[] + op[];
        Vector half = normalize(tmp);
        lighting[] += scene.specular * max(0, dot_product(norm, half)) ^^ scene.specular_power * 255.0;
    }
    if (refls < scene.max_refls && refl > 0.003) {
        Vector reflected = op[] + 2 * (project(op, norm)[] - op[]);
        tmp = col[] + 1e-6 * reflected[];
        lighting[] += (1 - amb) * refl * scene.color_ray(tmp, reflected, refls + 1)[];
    }
    return lighting;
}

Color color_point(Scene* scene, Point pt) {
    Vector dir = pt[] - scene.camera[];
    return color_ray(scene, pt, dir, 0);
}

Color color_pixel(Scene* scene, uint x, uint y, uint scale, uint antialias) {
    Color c = [0, 0, 0];
    foreach (i; 0 .. antialias) {
        double rx = (x + uniform(0.0, 1.0)) / scale;
        double ry = 1 - (y + uniform(0.0, 1.0)) / scale;
        c[] += color_point(scene, [rx, 0, ry])[];
    }
    c[] /= antialias;
    return c;
}

float parse_num(JSONValue v) {
    if (v.type == JSONType.integer) {
        return v.integer;
    } else if (v.type == JSONType.uinteger) {
        return v.uinteger;
    } else {
        return v.floating;
    }
}

Vector parse_vector(JSONValue[] arr) {
    Vector ret;
    foreach (i; 0 .. 3) {
        ret[i] = parse_num(arr[i]);
    }
    return ret;
}

void parse_scene(string filename, Scene* scene, uint* antialias) {
    JSONValue json = parseJSON(readText(filename));
    *antialias = cast(uint) json["antialias"].integer;
    scene.ambient = 0.2;
    scene.specular = 0.5;
    scene.specular_power = 8;
    scene.max_refls = 6;
    scene.background = [135, 206, 235];
    scene.light = parse_vector(json["light"].array);
    scene.camera = parse_vector(json["camera"].array);
    foreach (obj; json["objects"].array) {
        double refl = parse_num(obj["reflectivity"]);
        Color color = parse_vector(obj["color"].array);
        if (obj["type"].str == "sphere") {
            Point center = parse_vector(obj["center"].array);
            double radius = parse_num(obj["radius"]);
            scene.objects ~= new Sphere(refl, color, center, radius);
        } else {
            Point point = parse_vector(obj["point"].array);
            Vector normal = parse_vector(obj["normal"].array);
            bool checkerboard = obj["checkerboard"].boolean;
            if (checkerboard) {
                Color check_color = parse_vector(obj["color2"].array);
                Vector orientation = parse_vector(obj["orientation"].array);
                scene.objects ~= new Plane(refl, color, point, normal, check_color, orientation);
            } else {
                scene.objects ~= new Plane(refl, color, point, normal);
            }
        }
    }
}

int main(string[] argv) {
    if (argv.length != 3) {
        writeln("Usage: ./trace <config-file> <output-file>");
        return 1;
    }
    uint width = 512;
    uint height = 512;
    Scene scene;
    uint antialias;
    parse_scene(argv[1], &scene, &antialias);
    png.TrueColorImage img = new png.TrueColorImage(width, height);
    foreach (i; 0 .. height) {
        foreach (j; 0 .. width) {
            Color c = color_pixel(&scene, j, i, width, antialias);
            c[] /= 255;
            img.setPixel(j, i, png.Color(c[0], c[1], c[2], 1.0));
        }
    }
    png.writeImageToPngFile(argv[2], img);
    return 0;
}
