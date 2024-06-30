package main

import (
    "math"
    "os"
    "image"
    "flag"
    "fmt"
)
import rand "math/rand"
import color "image/color"
import png "image/png"
import json "encoding/json"

func offset(r Ray) Ray {
    return Ray{VAdd(r.Start, VMul(1e-6, r.Dir)), r.Dir}
}

type Scene struct {
    background Color
    light Point
    camera Point
    ambient float64
    specular float64
    specularPower float64
    maxRefls uint
    objects []Shape
}

func (self *Scene) AddObject(obj Shape) {
    self.objects = append(self.objects, obj)
}

func (self Scene) NearestIntersection(r Ray) (Shape, float64) {
    var obj Shape
    var mintime float64
    for _, v := range self.objects {
        time := v.Collision(r)
        if time > 0 && (obj == nil || time < mintime) {
            obj = v
            mintime = time
        }
    }
    return obj, mintime
}

func (self Scene) InShadow(p Point) bool {
    r := offset(Ray{p, VSub(self.light, p)})
    o, _ := self.NearestIntersection(r)
    return o != nil
}

func (self Scene) RayColor(r Ray, refls uint) Color {
    obj, t := self.NearestIntersection(r)
    if obj == nil {
        return self.background
    }
    col := VAdd(r.Start, VMul(t, r.Dir))
    refl := obj.Reflectivity()
    amb := self.ambient * (1 - refl)
    color := obj.Color(col)
    lighting := VMul(amb, color)
    norm := Normalize(obj.Normal(col))
    op := Normalize(VNeg(r.Dir))
    if !self.InShadow(col) {
        lightDir := Normalize(VSub(self.light, col))
        lighting = VAdd(lighting, VMul((1 - amb) * (1 - refl) *
            math.Max(0.0, DotProduct(norm, lightDir)), color))
        half := Normalize(VAdd(lightDir, op))
        lighting = VAdd(lighting, VMul(self.specular *
            math.Pow(math.Max(0.0, DotProduct(half, norm)), self.specularPower),
            [3]float64{255, 255, 255}))
    }
    if refls < self.maxRefls && refl > 0.003 {
        ref := VAdd(op, VMul(2, VSub(Project(op, norm), op)))
        lighting = VAdd(lighting, VMul((1 - amb) * refl,
            self.RayColor(offset(Ray{col, ref}), refls + 1)))
    }
    return lighting
}

func (self Scene) PointColor(p Point) Color {
    return self.RayColor(Ray{p, VSub(p, self.camera)}, 0)
}

func ColorPixel(scene Scene, x, y, scale int, antialias uint) Color {
    color := [3]float64{0.0, 0.0, 0.0}
    for i := uint(0); i < antialias; i++ {
        rx := (float64(x) + rand.Float64()) / float64(scale)
        ry := 1 - (float64(y) + rand.Float64()) / float64(scale)
        color = VAdd(color, scene.PointColor([3]float64{rx, 0, ry}))
    }
    return VMul(1.0 / float64(antialias), color)
}

func JsonToVec(data []any) [3]float64 {
    var ret [3]float64
    for i := 0; i < 3; i++ {
        ret[i] = data[i].(float64)
    }
    return ret
}

func ParseScene(filename string) (Scene, uint) {
    f, err := os.Open(filename)
    if err != nil {
        panic(err)
    }
    defer f.Close()
    dec := json.NewDecoder(f)
    var json map[string]any
    err = dec.Decode(&json)
    if err != nil {
        panic(err)
    }
    antialias := int(json["antialias"].(float64))
    light := JsonToVec(json["light"].([]any))
    camera := JsonToVec(json["camera"].([]any))
    var objects [0]Shape
    scene := Scene{
        Color{135, 206, 235},
        light,
        camera,
        0.2,
        0.5,
        8,
        6,
        objects[:],
    }
    for _, o := range json["objects"].([]any) {
        obj := o.(map[string]any)
        color := JsonToVec(obj["color"].([]any))
        refl := obj["reflectivity"].(float64)
        var shape Shape
        if obj["type"].(string) == "sphere" {
            center := JsonToVec(obj["center"].([]any))
            radius := obj["radius"].(float64)
            shape = Sphere{refl, color, center, radius}
        } else {
            point := JsonToVec(obj["point"].([]any))
            normal := JsonToVec(obj["normal"].([]any))
            checkerboard := obj["checkerboard"].(bool)
            checkColor := Color{0, 0, 0}
            orientation := Vec{0, 0, 0}
            if checkerboard {
                checkColor = JsonToVec(obj["color2"].([]any))
                orientation = JsonToVec(obj["orientation"].([]any))
            }
            shape = Plane{refl, color, point, normal, checkerboard,
                checkColor, orientation}
        }
        scene.AddObject(shape)
    }
    return scene, uint(antialias)
}

func main() {
    flag.Parse()
    args := flag.Args()
    if len(args) != 2 {
        fmt.Println(args)
        panic("Usage: trace <config-file> <output-file>")
    }

    scene, antialias := ParseScene(args[0])
    width := 512
    height := 512
    img := image.NewRGBA(image.Rect(0, 0, width, height))
    for i := 0; i < width; i++ {
        for j := 0; j < height; j++ {
            c := ColorPixel(scene, i, j, width, antialias)
            r := uint8(max(0, min(255, int(c[0] + 0.5))))
            g := uint8(max(0, min(255, int(c[1] + 0.5))))
            b := uint8(max(0, min(255, int(c[2] + 0.5))))
            color := color.RGBA{r, g, b, 255}
            img.Set(i, j, color)
        }
    }
    f, err := os.OpenFile(args[1], os.O_WRONLY | os.O_CREATE, 0644)
    if err != nil {
        panic(err)
    }
    defer f.Close()
    png.Encode(f, img)
}
