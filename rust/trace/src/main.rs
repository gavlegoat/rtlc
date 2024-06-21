mod shapes;
mod vector;

use crate::vector::{Point, Vector, Color, Ray};
use crate::shapes::{Shape, Sphere, Plane};

struct Scene {
    camera: Point,
    light: Point,
    ambient: f64,
    specular: f64,
    spec_power: u32,
    max_reflections: u32,
    background: Color,
    antialias: u32,
    objects: Vec<Box<dyn Shape>>,
}

impl Scene {
    fn nearest_intersection(&self, ray: Ray) -> Option<(f64, &Box<dyn Shape>)> {
        let mut best: Option<(f64, &Box<dyn Shape>)> = None;
        for s in &self.objects {
            let t = s.get_collision_time(ray);
            if t.is_none() {
                continue;
            }
            best = match best {
                None => Some((t?, &s)),
                Some((time, sh)) =>
                    if t? < time {
                        Some((t?, &s))
                    } else {
                        Some((time, sh))
                    },
            }
        }
        best
    }

    fn new(filename: &String) -> Option<Self> {
	let string = std::fs::read_to_string(filename).expect("Failed to read config file");
	let data: serde_json::Value = serde_json::from_str(&string).ok()?;
	let antialias = data.get("antialias")?.as_u64()?;
	let light = parse_point(data.get("light")?)?;
	let camera = parse_point(data.get("camera")?)?;
	let objects: Option<Vec<Box<dyn Shape>>> =
	    data.get("objects")?.as_array()?.into_iter().map(parse_shape).collect();
	Some(Scene {
	    camera: camera,
	    light: light,
	    ambient: 0.2,
	    specular: 0.5,
	    spec_power: 8,
	    max_reflections: 6,
	    background: Color { r: 135.0, g: 206.0, b: 235.0 },
	    antialias: antialias as u32,
	    objects: objects?,
	})
    }
}

fn color_ray(scene: &Scene, ray: Ray, refls: u32) -> Color {
    let int = scene.nearest_intersection(ray);
    if int.is_none() {
        return scene.background
    }
    let (t, obj) = int.unwrap();
    let col = ray.start + t * ray.direction;
    let r = obj.get_reflectivity();
    let amb = scene.ambient * (1.0 - r);
    let obj_color = obj.get_color(col);
    let l_amb = amb * obj_color;
    let light_dir = (scene.light - col).normalize();
    let in_shadow = scene.nearest_intersection(
        Ray { start: col + 1e-6 * light_dir,
              direction: light_dir }).is_some();
    let norm = obj.get_normal_vector(col).normalize();
    let l_diff = if in_shadow {
        Color { r: 0.0, g: 0.0, b: 0.0 }
    } else {
        (1.0 - amb) * (1.0 - r) *
            light_dir.dot(norm).max(0.0) * obj_color
    };
    let l_spec = if in_shadow {
        Color { r: 0.0, g: 0.0, b: 0.0 }
    } else {
        let half = (light_dir - ray.direction.normalize()).normalize();
        let w = Color { r: 255.0, g: 255.0, b: 255.0 };
        scene.specular * half.dot(norm).max(0.0).powf(scene.spec_power as f64) * w
    };
    let l_refl = if refls < scene.max_reflections && r > 0.003 {
        let v = -ray.direction.normalize();
        let diff = v.project(norm) - v;
        let refl = v + 2.0 * diff;
        r * color_ray(scene, Ray { start: col + 1e-6 * refl, direction: refl }, refls + 1)
    } else {
        Color { r: 0.0, g: 0.0, b: 0.0 }
    };
    l_amb + l_diff + l_spec + l_refl
}

fn color_point(scene: &Scene, p: Point) -> Color {
    color_ray(scene, Ray { start: p, direction: p - scene.camera }, 0)
}

fn color_pixel<T: rand::Rng>(scene: &Scene, x: u32, y: u32, rng: &mut T,
                             width: u32) -> Color {
    let mut color = Color { r: 0.0, g: 0.0, b: 0.0 };
    for _ in 0..scene.antialias {
        let xo: f64 = rng.gen();
        let yo: f64 = rng.gen();
        let px = (xo + x as f64) / (width as f64);
        let pz = 1.0 - (yo + y as f64) / (width as f64);
        color = color + color_point(scene, Point::new(px, 0.0, pz));
    }
    1.0 / scene.antialias as f64 * color
}

fn color_row<T: rand::Rng>(scene: &Scene, y: u32, rng: &mut T, width: u32) -> Vec<Color> {
    (0..width).map(|x| color_pixel(scene, x, y, rng, width)).collect()
}

fn parse_vector(json: &serde_json::Value) -> Option<Vector> {
    let arr = json.as_array()?;
    Some(Vector::new(arr.get(0)?.as_f64()?, arr.get(1)?.as_f64()?, arr.get(2)?.as_f64()?))
}

fn parse_point(json: &serde_json::Value) -> Option<Point> {
    let arr = json.as_array()?;
    Some(Point::new(arr.get(0)?.as_f64()?, arr.get(1)?.as_f64()?, arr.get(2)?.as_f64()?))
}

fn parse_color(json: &serde_json::Value) -> Option<Color> {
    Some(Color {
        r: json.get(0)?.as_f64()?,
        g: json.get(1)?.as_f64()?,
        b: json.get(2)?.as_f64()?,
    })
}

fn parse_shape(json: &serde_json::Value) -> Option<Box<dyn Shape>> {
    let color = parse_color(json.get("color")?)?;
    let refl = json.get("reflectivity")?.as_f64()?;
    let ty = json.get("type")?.as_str()?;
    if ty == "sphere" {
        let center = parse_point(json.get("center")?)?;
        let radius = json.get("radius")?.as_f64()?;
        Some(Box::new(Sphere::new(color, refl, center, radius)))
    } else if ty == "plane" {
        let point = parse_point(json.get("point")?)?;
        let normal = parse_vector(json.get("normal")?)?;
        let checkerboard = json.get("checkerboard")?.as_bool()?;
        if checkerboard {
            let ori = parse_vector(json.get("orientation")?)?;
            let ch_col = parse_color(json.get("color2")?)?;
            Some(Box::new(Plane::new(color, refl, point, normal, checkerboard,
                                     Some(ori), Some(ch_col))))
        } else {
            Some(Box::new(Plane::new(color, refl, point, normal, checkerboard,
                                     None, None)))
        }
    } else {
        None
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        println!("Usage: ./trace <config_file> <output_file>");
        std::process::exit(0);
    }
    let mut rng = rand::thread_rng();
    let width = 512;
    let height = 512;
    let scene = Scene::new(&args[1]).expect("Failed to parse scene");
    let pixels: Vec<Vec<Color>> = (0..height).map(|y| color_row(&scene, y, &mut rng,
                                                                width)).collect();
    let mut img = image::RgbImage::new(width, height);
    for i in 0..width as usize {
        for j in 0..height as usize {
            let r = pixels[j][i].r.round().max(0.0).min(255.0) as u8;
            let g = pixels[j][i].g.round().max(0.0).min(255.0) as u8;
            let b = pixels[j][i].b.round().max(0.0).min(255.0) as u8;
            img.put_pixel(i as u32, j as u32, image::Rgb([r, g, b]));
        }
    }
    img.save(&args[2]).expect("Unable to save image");
}
