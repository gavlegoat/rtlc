#[derive(Copy, Clone, Debug)]
pub struct Vector {
    x: f64,
    y: f64,
    z: f64,
}

impl std::fmt::Display for Vector {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "({}, {}, {})", self.x, self.y, self.z)
    }
}

impl std::ops::Add for Vector {
    type Output = Vector;

    fn add(self, other: Vector) -> Vector {
        Vector {
            x: self.x + other.x,
            y: self.y + other.y,
            z: self.z + other.z,
        }
    }
}

impl std::ops::Sub for Vector {
    type Output = Vector;

    fn sub(self, other: Vector) -> Vector {
        Vector {
            x: self.x - other.x,
            y: self.y - other.y,
            z: self.z - other.z,
        }
    }
}

impl std::ops::Neg for Vector {
    type Output = Vector;

    fn neg(self) -> Vector {
        Vector {
            x: -self.x,
            y: -self.y,
            z: -self.z
        }
    }
}

impl std::ops::Mul<Vector> for f64 {
    type Output = Vector;

    fn mul(self, v: Vector) -> Vector {
        Vector {
            x: self * v.x,
            y: self * v.y,
            z: self * v.z,
        }
    }
}

impl Vector {

    pub fn new(x: f64, y: f64, z: f64) -> Self {
        Vector { x, y, z }
    }

    pub fn dot(&self, v2: Vector) -> f64 {
        self.x * v2.x + self.y * v2.y + self.z * v2.z
    }

    pub fn project(&self, v2: Vector) -> Vector {
        self.dot(v2) / v2.dot(v2) * v2
    }

    pub fn magnitude(&self) -> f64 {
        (self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
    }

    pub fn normalize(self) -> Vector {
        1.0 / self.magnitude() * self
    }

}

#[derive(Copy, Clone, Debug)]
pub struct Point {
    p: Vector,
}

impl std::fmt::Display for Point {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{}", self.p)
    }
}

impl Point {
    pub fn new(x: f64, y: f64, z: f64) -> Self{
        Point { p: Vector::new(x, y, z) }
    }
}

impl std::ops::Sub for Point {
    type Output = Vector;

    fn sub(self, other: Point) -> Vector {
        self.p - other.p
    }
}

impl std::ops::Add<Vector> for Point {
    type Output = Point;

    fn add(self, other: Vector) -> Point {
        Point {
            p: self.p + other
        }
    }
}

#[derive(Copy, Clone)]
pub struct Ray {
    pub start: Point,
    pub direction: Vector,
}

#[derive(Copy, Clone)]
pub struct Color {
    pub r: f64,
    pub g: f64,
    pub b: f64,
}

impl std::ops::Add for Color {
    type Output = Color;

    fn add(self, c: Color) -> Color {
        Color {
            r: self.r + c.r,
            g: self.g + c.g,
            b: self.b + c.b,
        }
    }
}

impl std::ops::Mul<Color> for f64 {
    type Output = Color;

    fn mul(self, c: Color) -> Color {
        Color {
            r: self * c.r,
            g: self * c.g,
            b: self * c.b,
        }
    }
}
