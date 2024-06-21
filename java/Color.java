public class Color {
    private double red;
    private double green;
    private double blue;

    public Color(double r, double g, double b) {
        red = r;
        green = g;
        blue = b;
    }

    public Color mul(double c) {
        return new Color(c * red, c * green, c * blue);
    }

    public void update(Color c) {
        red += c.red;
        green += c.green;
        blue += c.blue;
    }

    public int toInt() {
        int r = Math.min(255, Math.max(0, (int) (red + 0.5)));
        int g = Math.min(255, Math.max(0, (int) (green + 0.5)));
        int b = Math.min(255, Math.max(0, (int) (blue + 0.5)));
        return (r << 16) | (g << 8) | b;
    }

    @Override
    public String toString() {
        return "Color(" + Double.toString(red) + ", " + Double.toString(green) +
        ", " + Double.toString(blue) + ")";
    }
}
