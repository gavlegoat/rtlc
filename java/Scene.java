import java.util.ArrayList;
import java.util.Optional;

public class Scene {
    private Vector lightPos;
    private Vector cameraPos;
    private double ambient;
    private double specular;
    private double specularPower;
    private int maxReflections;
    private Color backgroundColor;
    private ArrayList<Shape> objects;

    public Scene(Vector cam, Vector light) {
        lightPos = light;
        cameraPos = cam;
        ambient = 0.2;
        specular = 0.5;
        specularPower = 8;
        maxReflections = 6;
        backgroundColor = new Color(135, 206, 235);
        objects = new ArrayList<Shape>();
    }

    public void addShape(Shape sh) {
        objects.add(sh);
    }

    private Optional<Collision> getNearestIntersection(Vector st, Vector dir) {
        Optional<Collision> nearest = Optional.empty();
        for (Shape sh : objects) {
            Optional<Double> t = sh.getCollisionTime(st, dir);
            if (!t.isPresent()) {
                continue;
            }
            if (!nearest.isPresent() || t.get() < nearest.get().getTime()) {
                nearest = Optional.of(new Collision(t.get(), sh));
            }
        }
        return nearest;
    }

    private boolean inShadow(Vector pt) {
        Vector lightDir = lightPos.sub(pt);
        return getNearestIntersection(pt.add(lightDir.mul(1e-6)), lightDir).isPresent();
    }

    private Color getRayColor(Vector st, Vector dir, int refls) {
        Optional<Collision> res = getNearestIntersection(st, dir);
        if (!res.isPresent()) {
            return backgroundColor;
        }
        Vector col = st.add(dir.mul(res.get().getTime()));
        Shape obj = res.get().getObject();
        double refl = obj.getReflectivity();
        double amb = ambient * (1 - refl);
        Color lighting = obj.getColor(col).mul(amb);
        Vector norm = obj.getNormalVector(col).normalize();
        if (!inShadow(col)) {
            Vector lightDir = lightPos.sub(col).normalize();
            Vector halfWay = lightDir.add(dir.neg().normalize()).normalize();
            lighting.update(new Color(255, 255, 255).mul(
                specular * Math.max(0, Math.pow(halfWay.dotProduct(norm), specularPower))));
            lighting.update(obj.getColor(col).mul((1 - amb) * (1 - refl) *
                Math.max(0, norm.dotProduct(lightDir))));
        }
        if (refls < maxReflections && refl > 0.003) {
            Vector op = dir.neg().normalize();
            Vector ref = norm.add(op.project(norm).sub(op));
            lighting.update(getRayColor(col.add(ref.mul(1e-6)), ref, refls + 1)
                .mul((1 - amb) * refl));
        }
        return lighting;
    }

    public Color getPointColor(Vector pt) {
        return getRayColor(pt, pt.sub(cameraPos), 0);
    }
}
