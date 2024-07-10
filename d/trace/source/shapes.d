import vector;
import std.typecons;
import std.math;
import std.algorithm;

class Shape {
    protected double reflectivity;
    protected Color color;

    this(double refl, Color c) {
        reflectivity = refl;
        color = c;
    }

    double get_reflectivity() {
        return reflectivity;
    }

    Color get_color(Point pt) {
        return color;
    }

    abstract Vector get_normal(Point pt);

    abstract Nullable!double get_collision_time(Point pt, Vector dir);
}

class Sphere : Shape {
    private Point center;
    private double radius;

    this(double refl, Color c, Point pt, double r) {
        super(refl, c);
        center = pt;
        radius = r;
    }

    override Vector get_normal(Point pt) {
        Vector res = pt[] - center[];
        return res;
    }

    override Nullable!double get_collision_time(Point pt, Vector dir) {
        double a = dot_product(dir, dir);
        Vector v = pt[] - center[];
        double b = 2 * dot_product(dir, v);
        double c = dot_product(v, v) - radius * radius;
        double discr = b * b - 4 * a * c;
        if (discr < 0) {
            return Nullable!double();
        }
        double t1 = (-b + sqrt(discr)) / (2 * a);
        double t2 = (-b - sqrt(discr)) / (2 * a);
        if (t1 < 0) {
            if (t2 < 0) {
                return Nullable!double.init;
            }
            return Nullable!double(t2);
        }
        if (t2 < 0) {
            return Nullable!double(t1);
        }
        return Nullable!double(min(t2, t2));
    }
}

class Plane : Shape {
    private Point point;
    private Vector normal;
    private Nullable!Color check_color;
    private Nullable!Vector orientation;

    this(double refl, Color c, Point p, Vector n) {
        super(refl, c);
        point = p;
        normal = n;
    }

    this(double refl, Color c, Point p, Vector n, Color c2, Vector o) {
        this(refl, c, p, n);
        check_color = Nullable!Color(c2);
        orientation = Nullable!Vector(o);
    }

    override Color get_color(Point pt) {
        if (orientation.isNull) {
            return color;
        }
        Vector v = pt[] - point[];
        Vector x = project(v, orientation.get);
        Vector y = v[] - x[];
        int ix = cast(int) (magnitude(x) + 0.5);
        int iy = cast(int) (magnitude(y) + 0.5);
        if ((ix + iy) % 2 == 0) {
            return color;
        }
        return check_color.get;
    }

    override Vector get_normal(Point pt) {
        return normal;
    }

    override Nullable!double get_collision_time(Point pt, Vector dir) {
        double angle = dot_product(normal, dir);
        if (abs(angle) < 1e-6) {
            return Nullable!double.init;
        }
        Vector v = point[] - pt[];
        double t = dot_product(normal, v) / angle;
        if (t < 0) {
            return Nullable!double.init;
        }
        return Nullable!double(t);
    }
}
