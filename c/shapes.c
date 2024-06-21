#include <string.h>
#include <stdlib.h>
#include <math.h>

#include "shapes.h"
#include "types.h"

typedef struct {
    point center;
    double radius;
} sphere;

typedef struct {
    point point;
    vector normal;
    int checkerboard;
    vector orientation;
    color check_color;
} plane;

struct shape {
    enum { SPHERE, PLANE } type;
    union { sphere sphere; plane plane; } shape;
    double reflectivity;
    color color;
};

double get_collision_time(shape* sh, point p, vector v) {
    if (sh->type == SPHERE) {
        sphere* s = &sh->shape.sphere;
        double a = dot_product(v, v);
        vector diff = p_sub(p, s->center);
        double b = 2 * dot_product(diff, v);
        double c = dot_product(diff, diff) - s->radius * s->radius;
        double discr = b * b - 4 * a * c;
        if (discr < 0) {
            return -1;
        }
        double t1 = (-b + sqrt(discr)) / (2 * a);
        double t2 = (-b - sqrt(discr)) / (2 * a);
        if (t1 < 0) {
            return t2;
        }
        if (t2 < 0) {
            return t1;
        }
        return t1 < t2 ? t1 : t2;
    } else {
        plane* pl = &sh->shape.plane;
        if (fabs(dot_product(v, pl->normal)) < 1e-6) {
            return -1;
        }
        return dot_product(p_sub(pl->point, p), pl->normal) / dot_product(v, pl->normal);
    }
}

double get_reflectivity(shape* sh) {
    return sh->reflectivity;
}

vector get_normal_vector(shape* sh, point collision) {
    if (sh->type == SPHERE) {
        sphere* s = &sh->shape.sphere;
        return p_sub(collision, s->center);
    } else {
        return sh->shape.plane.normal;
    }
}

color get_color(shape* sh, point collision) {
    if (sh->type == PLANE) {
        plane* p = &sh->shape.plane;
        if (!p->checkerboard) {
            return sh->color;
        }
        vector v = p_sub(collision, p->point);
        vector x = project(v, p->orientation);
        vector y = v_sub(v, x);
        int ix = (int) (magnitude(x) + 0.5);
        int iy = (int) (magnitude(y) + 0.5);
        if ((ix + iy) % 2 == 0) {
            return sh->color;
        } else {
            return p->check_color;
        }
    }
    return sh->color;
}

double get_json_double(json_value* data) {
    if (data->type == json_integer) {
        return data->u.integer;
    } else {
        return data->u.dbl;
    }
}

shape* parse_shape(json_value* data) {
    shape* s = malloc(sizeof(shape));
    for (size_t i = 0; i < data->u.object.length; i++) {
        const char* n = data->u.object.values[i].name;
        json_value* v = data->u.object.values[i].value;
        if (strcmp(n, "type") == 0) {
            if (strcmp(v->u.string.ptr, "sphere") == 0) {
                s->type = SPHERE;
            } else {
                s->type = PLANE;
            }
            break;
        }
    }
    for (size_t i = 0; i < data->u.object.length; i++) {
        const char* n = data->u.object.values[i].name;
        json_value* v = data->u.object.values[i].value;
        if (strcmp(n, "color") == 0) {
            s->color.r = get_json_double(v->u.array.values[0]);
            s->color.g = get_json_double(v->u.array.values[1]);
            s->color.b = get_json_double(v->u.array.values[2]);
        } else if (strcmp(n, "reflectivity") == 0) {
            s->reflectivity = get_json_double(v);
        } else if (strcmp(n, "center") == 0) {
            s->shape.sphere.center.x = get_json_double(v->u.array.values[0]);
            s->shape.sphere.center.y = get_json_double(v->u.array.values[1]);
            s->shape.sphere.center.z = get_json_double(v->u.array.values[2]);
        } else if (strcmp(n, "radius") == 0) {
            s->shape.sphere.radius = get_json_double(v);
        } else if (strcmp(n, "point") == 0) {
            s->shape.plane.point.x = get_json_double(v->u.array.values[0]);
            s->shape.plane.point.y = get_json_double(v->u.array.values[1]);
            s->shape.plane.point.z = get_json_double(v->u.array.values[2]);
        } else if (strcmp(n, "normal") == 0) {
            s->shape.plane.normal.x = get_json_double(v->u.array.values[0]);
            s->shape.plane.normal.y = get_json_double(v->u.array.values[1]);
            s->shape.plane.normal.z = get_json_double(v->u.array.values[2]);
        } else if (strcmp(n, "checkerboard") == 0) {
            s->shape.plane.checkerboard = v->u.boolean;
        } else if (strcmp(n, "orientation") == 0) {
            s->shape.plane.orientation.x = get_json_double(v->u.array.values[0]);
            s->shape.plane.orientation.y = get_json_double(v->u.array.values[1]);
            s->shape.plane.orientation.z = get_json_double(v->u.array.values[2]);
        } else if (strcmp(n, "color2") == 0) {
            s->shape.plane.check_color.r = get_json_double(v->u.array.values[0]);
            s->shape.plane.check_color.g = get_json_double(v->u.array.values[1]);
            s->shape.plane.check_color.b = get_json_double(v->u.array.values[2]);
        }
    }
    return s;
}

void free_shape(shape* s) {
    free(s);
}
