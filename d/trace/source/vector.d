import std.algorithm;
import std.math;

alias Vector = double[3];
alias Point = double[3];
alias Color = double[3];

double dot_product(double[3] u, double[3] v) {
    double[3] t = u[] * v[];
    return sum(t[0..3]);
}

double magnitude(double[3] v) {
    return sqrt(dot_product(v, v));
}

double[3] normalize(double[3] v) {
    double[3] t = 1.0 / magnitude(v) * v[];
    return t;
}

double[3] project(double[3] u, double[3] v) {
    double[3] t = dot_product(u, v) / dot_product(v, v) * v[];
    return t;
}
