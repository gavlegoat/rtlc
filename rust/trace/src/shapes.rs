use crate::vector::{Ray, Point, Vector, Color};

pub trait Shape {
    fn get_collision_time(&self, ray: Ray) -> Option<f64>;
    fn get_normal_vector(&self, p: Point) -> Vector;
    fn get_color(&self, p: Point) -> Color;
    fn get_reflectivity(&self) -> f64;
}

struct ShapeBase {
    color: Color,
    reflectivity: f64,
}

pub struct Sphere {
    base: ShapeBase,
    center: Point,
    radius: f64,
}

impl Sphere {
    pub fn new(color: Color, reflectivity: f64, center: Point, radius: f64) -> Self {
        Sphere {
            base: ShapeBase {
                color,
                reflectivity,
            },
            center,
            radius,
        }
    }
}

impl Shape for Sphere {
    fn get_collision_time(&self, ray: Ray) -> Option<f64> {
        let a = ray.direction.dot(ray.direction);
        let v = ray.start - self.center;
        let b = 2.0 * ray.direction.dot(v);
        let c = v.dot(v) - self.radius * self.radius;
        let discr: f64 = b * b - 4.0 * a * c;
        if discr < 0.0 {
            return None;
        }
        let t1 = (-b - discr.sqrt()) / (2.0 * a);
        let t2 = (-b + discr.sqrt()) / (2.0 * a);
        if t1 < 0.0 {
            if t2 < 0.0 {
                None
            } else {
                Some(t2)
            }
        } else if t2 < 0.0 {
            Some(t1)
        } else {
            Some(t1.min(t2))
        }
    }

    fn get_normal_vector(&self, p: Point) -> Vector {
        p - self.center
    }

    fn get_color(&self, _p: Point) -> Color {
        self.base.color
    }

    fn get_reflectivity(&self) -> f64 {
        self.base.reflectivity
    }
}

pub struct Plane {
    base: ShapeBase,
    point: Point,
    normal: Vector,
    checkerboard: bool,
    orientation: Option<Vector>,
    check_color: Option<Color>,
}

impl Plane {
    pub fn new(color: Color, reflectivity: f64, point: Point, normal: Vector,
               checkerboard: bool, orientation: Option<Vector>,
               check_color: Option<Color>) -> Self {
        Plane {
            base: ShapeBase {
                color,
                reflectivity,
            },
            point,
            normal,
            checkerboard,
            orientation,
            check_color,
        }
    }
}

impl Shape for Plane {
    fn get_collision_time(&self, ray: Ray) -> Option<f64> {
        if self.normal.dot(ray.direction).abs() < 1e-6 {
            return None
        }
        let t = self.normal.dot(self.point - ray.start) / self.normal.dot(ray.direction);
        if t < 0.0 {
            None
        } else {
            Some(t)
        }
    }

    fn get_normal_vector(&self, _p: Point) -> Vector {
        self.normal
    }

    fn get_color(&self, p: Point) -> Color {
        if self.checkerboard {
            let v = p - self.point;
            let x = v.project(self.orientation.unwrap());
            let y = v - x;
            let val = (x.magnitude().round() + y.magnitude().round()) as i32;
            if val % 2 == 0 {
                self.base.color
            } else {
                self.check_color.unwrap()
            }
        } else {
            self.base.color
        }
    }

    fn get_reflectivity(&self) -> f64 {
        self.base.reflectivity
    }
}
