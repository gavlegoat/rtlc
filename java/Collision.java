public class Collision {
    private double time;
    private Shape object;

    public Collision(double t, Shape o) {
        time = t;
        object = o;
    }

    public double getTime() {
        return time;
    }

    public Shape getObject() {
        return object;
    }
}
