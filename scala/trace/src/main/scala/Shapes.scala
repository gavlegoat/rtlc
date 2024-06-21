import math.{sqrt, min, abs}
import upickle.default.{Reader, SimpleReader}
import upickle.core.{Abort, ObjVisitor}

trait Shape {
  def reflectivity: Double
  def getCollisionTime(r: Ray): Option[Double]
  def getColor(p: Point): Color
  def getNormalVector(p: Point): Vector
}

class Sphere(
  color: Color,
  refl: Double,
  center: Point,
  radius: Double) extends Shape {

  override def reflectivity: Double = this.refl

  override def getCollisionTime(r: Ray): Option[Double] = {
    val a = r.direction.dotProduct(r.direction)
    val b = 2 * (r.start - this.center).dotProduct(r.direction)
    val c = (r.start - this.center).dotProduct(r.start - this.center) -
      this.radius * this.radius
    val discr = b * b - 4 * a * c
    if discr < 0 then None
    else {
      val t1 = (-b + sqrt(discr)) / (2 * a)
      val t2 = (-b - sqrt(discr)) / (2 * a)
      if (t1 < 0) then
        if (t2 < 0) then
          None
        else
          Some(t2)
        end if
      else if (t2 < 0) then
        Some(t1)
      else
        Some(min(t1, t2))
    }
  }

  override def getColor(p: Point): Color = this.color

  override def getNormalVector(p: Point): Vector = p - this.center
}

class Plane(
  color: Color,
  refl: Double,
  point: Point,
  normal: Vector,
  checkerboard: Boolean,
  orientation: Option[Vector],
  check_color: Option[Color]) extends Shape {

  def this(color: Color, refl: Double, point: Point, normal: Vector) =
    this(color, refl, point, normal, false, None, None)

  def this(color: Color, refl: Double, point: Point, normal: Vector, ori: Vector, ch_color: Color) =
    this(color, refl, point, normal, true, Some(ori), Some(ch_color))

  override def reflectivity: Double = this.refl

  override def getCollisionTime(r: Ray): Option[Double] = {
    val d = r.direction.dotProduct(this.normal)
    if abs(d) < 1e-6 then
      None
    else {
      val t = (this.point - r.start).dotProduct(this.normal) / d;
      if t < 0 then
        None
      else
        Some(t)
    }
  }

  override def getColor(p: Point): Color = {
    val newValue = {
      val v = p - this.point
      val x = v.project(this.orientation.get)
      val y = v - x
      val ix = (x.magnitude() + 0.5).toInt
      val iy = (y.magnitude() + 0.5).toInt
      if (ix + iy) % 2 == 0 then
        this.color
      else
        this.check_color.get
    }
    if !this.checkerboard then
      this.color
    else newValue
  }

  override def getNormalVector(p: Point): Vector = this.normal
}

