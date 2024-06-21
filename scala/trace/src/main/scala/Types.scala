import math.sqrt
import language.implicitConversions
import upickle.default.{Reader, SimpleReader}
import upickle.core.{Abort, ArrVisitor}

case class Vector(x: Double, y: Double, z: Double) {
  def +(other: Vector): Vector =
    Vector(this.x + other.x, this.y + other.y, this.z + other.z)
  def -(other: Vector): Vector =
    Vector(this.x - other.x, this.y - other.y, this.z - other.z)
  def unary_- =
    Vector(-this.x, -this.y, -this.z)
  def magnitude(): Double =
    sqrt(this.x * this.x + this.y * this.y + this.z * this.z)
  def normalize: Vector = 1 / this.magnitude() * this
  def dotProduct(other: Vector): Double =
    this.x * other.x + this.y * other.y + this.z * other.z
  def project(other: Vector): Vector =
    this.dotProduct(other) / other.dotProduct(other) * other
}

given Reader[Vector] = new SimpleReader[Vector] {
  override def expectedMsg = "expected vector"
  override def visitArray(length: Int, index: Int) = new ArrVisitor[Any, Vector] {
    var x: Option[Double] = None
    var y: Option[Double] = None
    var z: Option[Double] = None
    override def visitValue(v: Any, index: Int) = {
      if x.isEmpty then
      x = Some(v.asInstanceOf[Double])
      else if y.isEmpty then
      y = Some(v.asInstanceOf[Double])
      else if z.isEmpty then
      z = Some(v.asInstanceOf[Double])
    else
      throw new Abort("Too many values in vector")
    }
    override def visitEnd(index: Int) =
      Vector(x.get, y.get, z.get)
    override def subVisitor = implicitly[Reader[Double]]
  }
}

case class Point(x: Double, y: Double, z: Double) {
  def +(other: Vector): Point =
    Point(this.x + other.x, this.y + other.y, this.z + other.z)
  def -(other: Point): Vector =
    Vector(this.x - other.x, this.y - other.y, this.z - other.z)
}

given Reader[Point] = new SimpleReader[Point] {
  override def expectedMsg = "expected point"
  override def visitArray(length: Int, index: Int) = new ArrVisitor[Any, Point] {
    var x: Option[Double] = None
    var y: Option[Double] = None
    var z: Option[Double] = None
    override def visitValue(v: Any, index: Int) = {
      if x.isEmpty then
      x = Some(v.asInstanceOf[Double])
      else if y.isEmpty then
      y = Some(v.asInstanceOf[Double])
      else if z.isEmpty then
      z = Some(v.asInstanceOf[Double])
    else
      throw new Abort("Too many values in point")
    }
    override def visitEnd(index: Int) =
      Point(x.get, y.get, z.get)
    override def subVisitor = implicitly[Reader[Double]]
  }
}

case class Color(r: Double, g: Double, b: Double) {
  def +(other: Color): Color =
    Color(this.r + other.r, this.g + other.g, this.b + other.b)
}

given Reader[Color] = new SimpleReader[Color] {
  override def expectedMsg = "expected color"
  override def visitArray(length: Int, index: Int) = new ArrVisitor[Any, Color] {
    var r: Option[Double] = None
    var g: Option[Double] = None
    var b: Option[Double] = None
    override def visitValue(v: Any, index: Int) = {
      if r.isEmpty then
      r = Some(v.asInstanceOf[Double])
      else if g.isEmpty then
      g = Some(v.asInstanceOf[Double])
      else if b.isEmpty then
      b = Some(v.asInstanceOf[Double])
    else
      throw new Abort("Too many values in color")
    }
    override def visitEnd(index: Int) =
      Color(r.get, g.get, b.get)
    override def subVisitor = implicitly[Reader[Double]]
  }
}

case class Scalar(x: Double) {
  def *(other: Vector): Vector =
    Vector(this.x * other.x, this.x * other.y, this.x * other.z)
  def *(other: Color): Color =
    Color(this.x * other.r, this.x * other.g, this.x * other.b)
}

given Conversion[Double, Scalar] = (x: Double) => Scalar(x)
given Conversion[Int, Scalar] = (x: Int) => Scalar(x)

case class Ray(start: Point, direction: Vector)
