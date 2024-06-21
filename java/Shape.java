import java.util.Optional;

public abstract class Shape {
    protected double reflectivity;
    protected Color color;

    public Shape(double refl, Color col) {
        reflectivity = refl;
        color = col;
    }

    public double getReflectivity() {
        return reflectivity;
    }

    public abstract Color getColor(Vector pt);

    public abstract Vector getNormalVector(Vector pt);

    public abstract Optional<Double> getCollisionTime(Vector st, Vector dir);
}
