#include <stdlib.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#include "shapes.h"
#include "json.h"
#include "libattopng.h"

#define WIDTH 512
#define HEIGHT 512

typedef struct {
    point camera;
    point light;
    double ambient;
    double specular;
    unsigned spec_power;
    unsigned max_reflections;
    color background;
    unsigned antialias;
    shape** objects;
    unsigned objects_length;
} scene;

typedef struct {
    double time;
    shape* object;
} intersection;

void free_scene(scene* s) {
    for (size_t i = 0; i < s->objects_length; i++) {
        free_shape(s->objects[i]);
    }
    free(s->objects);
    free(s);
}

intersection nearest_intersection(scene* scene, point start, vector dir) {
    intersection it;
    it.time = -1;
    for (unsigned i = 0; i < scene->objects_length; i++) {
        double t = get_collision_time(scene->objects[i], start, dir);
        if (t > 0 && (it.time <= 0 || t < it.time)) {
            it.time = t;
            it.object = scene->objects[i];
        }
    }
    return it;
}

double max(double a, double b) {
    if (a > b) {
        return a;
    }
    return b;
}

color ray_color(scene* scene, point start, vector dir, unsigned refls) {
    intersection it = nearest_intersection(scene, start, dir);
    if (it.time <= 0) {
        return scene->background;
    }
    shape* hit = it.object;
    point col = p_add(start, v_mul(it.time, dir));
    double re = get_reflectivity(hit);
    double amb = scene->ambient * (1 - re);
    color obj_color = get_color(hit, col);
    color lighting = c_mul(amb, obj_color);
    vector light_dir = p_sub(scene->light, col);
    it = nearest_intersection(scene, p_add(col, v_mul(1e-6, light_dir)), light_dir);
    if (it.time <= 0) {
        // Direct light
        light_dir = v_mul(1 / magnitude(light_dir), light_dir);
        vector norm = get_normal_vector(hit, col);
        norm = v_mul(1 / magnitude(norm), norm);
        lighting = c_add(lighting, c_mul((1 - amb) * (1 - re) *
                                         max(0, dot_product(norm, light_dir)),
                                         obj_color));
        vector v = v_mul(1 / magnitude(dir), v_neg(dir));
        vector half = v_add(v, light_dir);
        half = v_mul(1 / magnitude(half), half);
        color white;
        white.r = 255;
        white.g = 255;
        white.b = 255;
        lighting = c_add(lighting, c_mul(scene->specular *
                                         pow(max(0, dot_product(half, norm)),
                                             scene->spec_power),
                                         white));
    }
    if (refls < scene->max_reflections && re > 0.003) {
        vector v = v_mul(1 / magnitude(dir), v_neg(dir));
        vector diff = v_sub(project(v, get_normal_vector(hit, col)), v);
        vector refl = v_add(v, v_mul(2, diff));
        color r = ray_color(scene, p_add(col, v_mul(1e-6, refl)), refl, refls + 1);
        lighting = c_add(lighting, c_mul((1 - amb) * re, r));
    }
    return lighting;
}

color point_color(scene* scene, point p) {
    return ray_color(scene, p, p_sub(p, scene->camera), 0);
}

scene* parse_config(char* filename) {
    FILE* jsonfile = fopen(filename, "r");
    fseek(jsonfile, 0, SEEK_END);
    unsigned size = ftell(jsonfile);
    fseek(jsonfile, 0, SEEK_SET);
    char* json = malloc(size + 1);
    fread(json, size, 1, jsonfile);
    fclose(jsonfile);
    json[size] = '\0';
    json_value* data = json_parse(json, size);
    free(json);

    scene* s = malloc(sizeof(scene));
    s->ambient = 0.2;
    s->specular = 0.5;
    s->spec_power = 8;
    s->max_reflections = 6;
    s->background.r = 135;
    s->background.g = 206;
    s->background.b = 235;
    for (size_t i = 0; i < data->u.object.length; i++) {
        const char* n = data->u.object.values[i].name;
        json_value* v = data->u.object.values[i].value;
        if (strcmp(n, "light") == 0) {
            s->light.x = get_json_double(v->u.array.values[0]);
            s->light.y = get_json_double(v->u.array.values[1]);
            s->light.z = get_json_double(v->u.array.values[2]);
        } else if (strcmp(n, "camera") == 0) {
            s->camera.x = get_json_double(v->u.array.values[0]);
            s->camera.y = get_json_double(v->u.array.values[1]);
            s->camera.z = get_json_double(v->u.array.values[2]);
        } else if (strcmp(n, "antialias") == 0) {
            s->antialias = v->u.integer;
        } else if (strcmp(n, "objects") == 0) {
            s->objects = malloc(v->u.array.length * sizeof(shape*));
            s->objects_length = v->u.array.length;
            for (size_t j = 0; j < v->u.array.length; j++) {
                s->objects[j] = parse_shape(v->u.array.values[j]);
            }
        }
    }
    json_value_free(data);
    return s;
}

unsigned clip(int x) {
    if (x > 255) {
        return 255;
    }
    if (x < 0) {
        return 0;
    }
    return x;
}

int main(int argc, char** argv) {
    if (argc != 3) {
        printf("Usage: ./trace <config-file> <output-file>\n");
        return 0;
    }
    scene* scene = parse_config(argv[1]);
    color pixels[HEIGHT][WIDTH];
    srand(0);
    for (unsigned i = 0; i < HEIGHT; i++) {
        for (unsigned j = 0; j < WIDTH; j++) {
            color c;
            c.r = 0;
            c.g = 0;
            c.b = 0;
            for (unsigned k = 0; k < scene->antialias; k++) {
                double x = ((double) i) / WIDTH;
                double z = 1 - ((double) j) / WIDTH;
                double xr = ((double) rand()) / RAND_MAX;
                double zr = ((double) rand()) / RAND_MAX;
                x += xr / WIDTH;
                z += zr / WIDTH;
                point p;
                p.x = x;
                p.y = 0;
                p.z = z;
                color t = point_color(scene, p);
                c = c_add(c, t);
            }
            pixels[i][j] = c_mul(1.0 / scene->antialias, c);
        }
    }

    libattopng_t* png = libattopng_new(WIDTH, HEIGHT, PNG_RGB);
    for (size_t i = 0; i < HEIGHT; i++) {
        for (size_t j = 0; j < WIDTH; j++) {
            unsigned v = 0;
            v |= clip((int) pixels[i][j].r);
            v |= clip((int) pixels[i][j].g) << 8;
            v |= clip((int) pixels[i][j].b) << 16;
            libattopng_set_pixel(png, i, j, v);
        }
    }
    libattopng_save(png, argv[2]);
    libattopng_destroy(png);

    free_scene(scene);
}
