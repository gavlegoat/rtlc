require 'json'
require 'chunky_png'

load 'shapes.rb'

class Scene
  def initialize(light, camera)
    @light = light
    @camera = camera
    @ambient = 0.2
    @specular = 0.5
    @specular_power = 8
    @max_reflections = 6
    @background = Vector[135, 206, 235]
    @objects = Array.new
  end
  def self.from_file(filename)
    data = JSON.parse(File.read(filename))
    light = Vector.elements(data["light"])
    camera = Vector.elements(data["camera"])
    scene = Scene.new(light, camera)
    for o in data["objects"] do
      if o["type"] == "sphere"
        obj = Sphere.new(
          o["reflectivity"],
          Vector.elements(o["color"]),
          Vector.elements(o["center"]),
          o["radius"]
        )
        scene.add_object(obj)
      else
        if o["checkerboard"]
          obj = Plane.new(
            o["reflectivity"],
            Vector.elements(o["color"]),
            Vector.elements(o["point"]),
            Vector.elements(o["normal"]),
            true,
            Vector.elements(o["color2"]),
            Vector.elements(o["orientation"])
          )
          scene.add_object(obj)
        else
          obj = Plane.new(
            o["reflectivity"],
            Vector.elements(o["color"]),
            Vector.elements(o["point"]),
            Vector.elements(o["normal"])
          )
          scene.add_object(obj)
        end
      end
    end
    [scene, data["antialias"]]
  end

  def add_object(obj)
    @objects << obj
  end

  def nearest_intersection(pt, dir)
    @objects.reduce(nil) { |min, obj|
      t = obj.collision_time(pt, dir)
      if t != nil and (min == nil or t < min[0])
        [t, obj]
      else
        min
      end
    }
  end

  def in_shadow(pt)
    dir = @light - pt
    pt += 1e-6 * dir
    nearest_intersection(pt, dir) != nil
  end

  def color_ray(pt, dir, refls)
    res = nearest_intersection(pt, dir)
    if res == nil
      return @background
    end
    t, obj = res
    col = pt + t * dir
    amb = @ambient * (1 - obj.reflectivity)
    lighting = amb * obj.color(col)
    norm = obj.normal(col).normalize
    if not in_shadow(col)
      light_dir = (@light - col).normalize
      lighting += (1 - amb) * (1 - obj.reflectivity) * \
        [0, norm.dot(light_dir)].max * obj.color(col)
      half = (light_dir - dir.normalize).normalize
      lighting += @specular * [0, half.dot(norm)].max ** @specular_power * \
        Vector[255, 255, 255]
    end
    if refls < @max_reflections and obj.reflectivity > 0.003
      op = -dir.normalize
      ref = op + 2 * (project(op, norm) - op)
      lighting += (1 - amb) * obj.reflectivity * \
        color_ray(col + 1e-6 * ref, ref, refls + 1)
    end
    lighting
  end

  def color_point(pt)
    color_ray(pt, pt - @camera, 0)
  end
end

def color_pixel(scene, x, y, scale, antialias)
  color = Vector[0, 0, 0]
  for _ in 1..antialias do
    rx = (x + rand) / scale
    ry = 1 - (y + rand) / scale
    color += scene.color_point(Vector[rx, 0, ry])
  end
  color / antialias
end

def main(config_file, output_file)
  scene, antialias = Scene.from_file(config_file)
  width = 512
  height = 512
  img = ChunkyPNG::Image.new(width, height)
  for i in 0..height-1 do
    for j in 0..width-1 do
      color = color_pixel(scene, j, i, width, antialias)
      icol = ChunkyPNG::Color.rgb(
        [0, [255, color[0].round].min].max,
        [0, [255, color[1].round].min].max,
        [0, [255, color[2].round].min].max
      )
      img.set_pixel(j, i, icol)
    end
  end
  img.save(output_file)
end

if __FILE__ == $0
  if ARGV.count != 2
    puts "Usage: ruby main.rb <config-file> <output-file>"
  else
    main(ARGV[0], ARGV[1])
  end
end
