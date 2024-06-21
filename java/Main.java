import org.json.JSONObject;
import org.json.JSONArray;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Random;
import javax.imageio.ImageIO;

class Main {
    private static final int WIDTH = 512;
    private static final int HEIGHT = 512;

    private static Scene parseScene(JSONObject json) {
        JSONArray arr = json.getJSONArray("camera");
        Vector camera = new Vector(arr.getDouble(0), arr.getDouble(1), arr.getDouble(2));
        arr = json.getJSONArray("light");
        Vector light = new Vector(arr.getDouble(0), arr.getDouble(1), arr.getDouble(2));

        Scene scene = new Scene(camera, light);

        arr = json.getJSONArray("objects");
        for (Object o : arr) {
            JSONObject data = (JSONObject) o;
            double refl = data.getDouble("reflectivity");
            arr = data.getJSONArray("color");
            Color c = new Color(arr.getDouble(0), arr.getDouble(1), arr.getDouble(2));
            if (data.getString("type").equals("sphere")) {
                double rad = data.getDouble("radius");
                arr = data.getJSONArray("center");
                Vector center = new Vector(arr.getDouble(0), arr.getDouble(1), arr.getDouble(2));
                scene.addShape(new Sphere(refl, c, center, rad));
            } else {
                arr = data.getJSONArray("point");
                Vector pt = new Vector(arr.getDouble(0), arr.getDouble(1), arr.getDouble(2));
                arr = data.getJSONArray("normal");
                Vector norm = new Vector(arr.getDouble(0), arr.getDouble(1), arr.getDouble(2));
                boolean ch = data.getBoolean("checkerboard");
                if (ch) {
                    arr = data.getJSONArray("orientation");
                    Vector ori = new Vector(arr.getDouble(0), arr.getDouble(1), arr.getDouble(2));
                    arr = data.getJSONArray("color2");
                    Color c2 = new Color(arr.getDouble(0), arr.getDouble(1), arr.getDouble(2));
                    scene.addShape(new Plane(refl, c, pt, norm, ori, c2));
                } else {
                    scene.addShape(new Plane(refl, c, pt, norm));
                }
            }
        }
        return scene;
    }

    public static void main(String[] args) throws IOException {
        if (args.length != 2) {
            System.err.println("Usage: java Main <config-file> <output-file>");
            System.exit(1);
        }
        String jsonText = Files.readString(Paths.get(args[0]));
        JSONObject json = new JSONObject(jsonText);
        int antialias = json.getInt("antialias");
        Scene scene = parseScene(json);

        BufferedImage img = new BufferedImage(
            WIDTH, HEIGHT, BufferedImage.TYPE_INT_RGB);

        Random rng = new Random();

        for (int i = 0; i < WIDTH; i++) {
            for (int j = 0; j < HEIGHT; j++) {
                Color color = new Color(0, 0, 0);
                for (int k = 0; k < antialias; k++) {
                    double x = (i + rng.nextDouble()) / WIDTH;
                    double y = 1 - (j + rng.nextDouble()) / WIDTH;
                    color.update(scene.getPointColor(new Vector(x, 0, y)));
                }
                color = color.mul(1.0 / antialias);
                img.setRGB(i, j, color.toInt());
            }
        }

        ImageIO.write(img, "png", new File(args[1]));
    }
}
