import java.util.Optional;

public class Plane extends Shape {
    private Vector point;
    private Vector normal;
    private boolean checkerboard;
    private Vector orientation;
    private Color checkColor;

    public Plane(double refl, Color col, Vector pt, Vector norm) {
        super(refl, col);
        point = pt;
        normal = norm;
        checkerboard = false;
        orientation = new Vector(0, 0, 0);
        checkColor = new Color(0, 0, 0);
    }

    public Plane(double refl, Color col, Vector pt, Vector norm, Vector ori, Color c) {
        super(refl, col);
        point = pt;
        normal = norm;
        checkerboard = true;
        orientation = ori;
        checkColor = c;
    }

    @Override
    public Color getColor(Vector pt) {
        if (!checkerboard) {
            return color;
        }
        Vector v = pt.sub(point);
        Vector x = v.project(orientation);
        Vector y = v.sub(x);
        int ix = (int) (x.magnitude() + 0.5);
        int iy = (int) (y.magnitude() + 0.5);
        if ((ix + iy) % 2 == 0) {
            return color;
        }
        return checkColor;
    }

    @Override
    public Vector getNormalVector(Vector pt) {
        return normal;
    }

    @Override
    public Optional<Double> getCollisionTime(Vector st, Vector dir) {
        double angle = normal.dotProduct(dir);
        if (Math.abs(angle) < 1e-6) {
            return Optional.empty();
        }
        double t = normal.dotProduct(point.sub(st)) / angle;
        if (t < 0) {
            return Optional.empty();
        }
        return Optional.of(t);
    }
}
