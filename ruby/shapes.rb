require 'matrix'

def project(v, u)
  v.dot(u) / u.dot(u) * u
end

class Shape
  attr_reader :reflectivity
  def initialize(refl, col)
    @reflectivity = refl
    @color = col
  end
end

class Sphere < Shape
  def initialize(refl, col, pt, rad)
    super(refl, col)
    @center = pt
    @radius = rad
  end

  def color(pt)
    @color
  end

  def normal(pt)
    pt - @center
  end

  def collision_time(pt, dir)
    a = dir.dot(dir)
    v = pt - @center
    b = 2 * dir.dot(v)
    c = v.dot(v) - @radius ** 2
    discr = b ** 2 - 4 * a * c
    if discr < 0
      return nil
    end
    t1 = (-b + Math.sqrt(discr)) / (2 * a)
    t2 = (-b - Math.sqrt(discr)) / (2 * a)
    if t1 < 0
      if t2 < 0
        return nil
      end
      return t2
    end
    if t2 < 0
      return t1
    end
    [t1, t2].min
  end
end

class Plane < Shape
  def initialize(refl, col, pt, norm, ch=false, ch_c=nil, ori=nil)
    super(refl, col)
    @point = pt
    @normal = norm
    @checkerboard = ch
    @check_color = ch_c
    @orientation = ori
  end

  def color(pt)
    if not @checkerboard
      return @color
    end
    v = pt - @point
    x = project(v, @orientation)
    y = v - x
    if (x.magnitude.round + y.magnitude.round) % 2 == 0
      @color
    else
      @check_color
    end
  end

  def normal(pt)
    @normal
  end

  def collision_time(pt, dir)
    angle = @normal.dot(dir)
    if angle.abs < 1e-6
      return nil
    end
    t = @normal.dot(@point - pt) / angle
    if t < 0
      return nil
    end
    t
  end
end
