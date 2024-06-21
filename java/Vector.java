public class Vector {
    private double x;
    private double y;
    private double z;

    public Vector(double x, double y, double z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    public Vector add(Vector other) {
        return new Vector(x + other.x, y + other.y, z + other.z);
    }

    public Vector sub(Vector other) {
        return new Vector(x - other.x, y - other.y, z - other.z);
    }

    public Vector mul(double c) {
        return new Vector(c * x, c * y, c * z);
    }

    public Vector neg() {
        return new Vector(-x, -y, -z);
    }

    public double dotProduct(Vector other) {
        return x * other.x + y * other.y + z * other.z;
    }

    public double magnitude() {
        return Math.sqrt(dotProduct(this));
    }

    public Vector normalize() {
        return mul(1 / magnitude());
    }

    public Vector project(Vector other) {
        return other.mul(dotProduct(other) / other.dotProduct(other));
    }
}
