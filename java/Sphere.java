import java.util.Optional;

public class Sphere extends Shape {
    private Vector center;
    private double radius;

    public Sphere(double refl, Color col, Vector cen, double rad) {
        super(refl, col);
        center = cen;
        radius = rad;
    }

    @Override
    public Color getColor(Vector pt) {
        return color;
    }

    @Override
    public Vector getNormalVector(Vector pt) {
        return pt.sub(center);
    }

    @Override
    public Optional<Double> getCollisionTime(Vector st, Vector dir) {
        double a = dir.dotProduct(dir);
        Vector v = st.sub(center);
        double b = 2 * dir.dotProduct(v);
        double c = v.dotProduct(v) - radius * radius;
        double discr = b * b - 4 * a * c;
        if (discr < 0) {
            return Optional.empty();
        }
        double t1 = (-b + Math.sqrt(discr)) / (2 * a);
        double t2 = (-b - Math.sqrt(discr)) / (2 * a);
        if (t1 < 0) {
            if (t2 < 0) {
                return Optional.empty();
            }
            return Optional.of(t2);
        }
        if (t2 < 0) {
            return Optional.of(t2);
        }
        return Optional.of(Math.min(t1, t2));
    }
}
