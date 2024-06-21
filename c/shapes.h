#pragma once

#include "types.h"
#include "json.h"

typedef struct shape shape;

vector get_normal_vector(shape*, point);
color get_color(shape*, point);
double get_collision_time(shape*, point, vector);
double get_reflectivity(shape*);

double get_json_double(json_value*);
shape* parse_shape(json_value*);
void free_shape(shape*);
