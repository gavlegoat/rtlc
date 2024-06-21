import language.implicitConversions
import math.{min, max, pow}
import util.Random
import upickle.default.read
import java.awt.image.BufferedImage

class Scene(
  camera: Point,
  light: Point,
  ambient: Double,
  specular: Double,
  specPower: Int,
  maxReflections: Int,
  background: Color,
  objects: List[Shape]) {

  def nearestIntersection(r: Ray): Option[(Double, Shape)] = {
    objects.foldRight(None)((o: Shape, acc: Option[(Double, Shape)]) => {
      val t = o.getCollisionTime(r).map((_, o))
      acc.fold(t)(best => t.fold(acc)(tt => if tt(0) < best(0) then t else acc))
    })
  }

  def getRayColor(ray: Ray, refls: Int): Color = {
    this.nearestIntersection(ray) match {
      case None => this.background
      case Some((time, obj)) => {
        val collision = ray.start + time * ray.direction
        val c = obj.getColor(collision)
        val r = obj.reflectivity
        val amb = this.ambient * (1 - r)
        val lAmb = amb * c
        val lightDir = (this.light - collision).normalize
        val inShadow = this.nearestIntersection(
          Ray(collision + 1e-6 * lightDir, lightDir)).isDefined
        val norm = obj.getNormalVector(collision).normalize
        val lDiff = if inShadow then Color(0, 0, 0) else {
          (1 - amb) * (1 - r) * max(0, norm.dotProduct(lightDir)) * c
        }
        val lSpec = if inShadow then Color(0, 0, 0) else {
          val half = (lightDir - ray.direction.normalize).normalize
          this.specular * pow(max(0, half.dotProduct(norm)),
            this.specPower) * Color(255, 255, 255)
        }
        val lRefl = if refls < this.maxReflections && r > 0.003 then {
          val v = -ray.direction.normalize
          val diff = v.project(norm) - v
          val refl = v + 2 * diff
          r * this.getRayColor(Ray(collision + 1e-6 * refl, refl), refls + 1)
        } else Color(0, 0, 0)
        lAmb + lDiff + lSpec + lRefl
      }
    }
  }

  def getPointColor(p: Point): Color =
    this.getRayColor(Ray(p, p - camera), 0)
}

def parseSphere(data: ujson.Value): Sphere = {
  val refl = read[Double](data("reflectivity"))
  val color = read[Color](data("color"))
  val radius = read[Double](data("radius"))
  val center = read[Point](data("center"))
  Sphere(color, refl, center, radius)
}

def parsePlane(data: ujson.Value): Plane = {
  val refl = read[Double](data("reflectivity"))
  val color = read[Color](data("color"))
  val point = read[Point](data("point"))
  val norm = read[Vector](data("normal"))
  if read[Boolean](data("checkerboard")) then {
    val color2 = read[Color](data("color2"))
    val ori = read[Vector](data("orientation"))
    Plane(color, refl, point, norm, ori, color2)
  } else Plane(color, refl, point, norm)
}

def parseObject(data: ujson.Value): Shape =
  if data("type").str == "sphere" then
    parseSphere(data)
  else if data("type").str == "plane" then
    parsePlane(data)
  else
    throw new Exception("Unknown object type " + data("type").str)

def parseScene(fn: String): (Scene, Int) = {
  val json = ujson.read(os.read(os.FilePath(fn).resolveFrom(os.pwd)))

  val camera = read[Point](json("camera"))
  val light = read[Point](json("light"))
  val antialias = read[Int](json("antialias"))

  val objects: List[Shape] = json("objects").arr.map(parseObject).toList

  (Scene(camera, light, 0.2, 0.5, 8, 6, Color(135, 206, 235), objects), antialias)
}

def getPixelColor(scene: Scene, x: Int, y: Int, width: Int, antialias: Int,
  rng: Random): Color = {
  (1.0 / antialias) * (0 until antialias).map(_ => {
    val xv = (x.toDouble + rng.nextDouble) / width
    val yv = 1 - (y.toDouble + rng.nextDouble) / width
    scene.getPointColor(Point(xv, 0, yv))
  }).foldRight(Color(0, 0, 0))(_ + _)
}

def getRowColors(scene: Scene, y: Int, width: Int, antialias: Int,
  rng: Random): IndexedSeq[Color] =
  (0 until width).map(getPixelColor(scene, _, y, width, antialias, rng))

def convertColor(c: Color): Int = {
  val r = min(max(c.r.toInt, 0), 255)
  val g = min(max(c.g.toInt, 0), 255)
  val b = min(max(c.b.toInt, 0), 255)
  (r << 16) | (g << 8) | b;
}

def writeImage(pixels: IndexedSeq[IndexedSeq[Color]], fn: String): Unit = {
  val img = new BufferedImage(pixels.size, pixels(0).size, BufferedImage.TYPE_INT_RGB)

  (0 until pixels.size).map(x => (0 until pixels(x).size).map(y =>
    img.setRGB(x, y, convertColor(pixels(y)(x)))))

  javax.imageio.ImageIO.write(img, "png", new java.io.File(fn))
}

@main def main(configFile: String, outputFile: String): Unit = {
  val (scene, antialias) = parseScene(configFile)
  val imageWidth = 512
  val imageHeight = 512
  val rng = Random()
  val pixels = (0 until imageHeight).map(getRowColors(scene, _, imageWidth,
    antialias, rng))
  writeImage(pixels, outputFile)
}
