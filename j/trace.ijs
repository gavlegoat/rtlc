#!/Applications/j9.4/bin/jconsole

NB. Ray Tracing

NB. Data Representation
NB.
NB. A scene has several components
NB. - camera (3-vector, position)
NB. - light (3-vector, position)
NB. - ambient (scalar)
NB. - specular (scalar)
NB. - specular_power (integer)
NB. - max_reflections (integer)
NB. - background (3-vector, color)
NB. - image_shape (2-vector, width x height)
NB. - antialias (integer)
NB. - spheres (array of spheres)
NB. - planes (array of planes)
NB.
NB. The scene is assumed to be held in global variables with the
NB. names given above.
NB.
NB. Each object is an array consisting of:
NB. - reflectivity (scalar)
NB. - color (3-vector, color)
NB. - shape (either sphere or plane)
NB.
NB. A sphere has
NB. - center (3-vector, position)
NB. - radius (scalar)
NB.
NB. A plane has
NB. - point (3-vector, position)
NB. - normal (3-vector)
NB. - Optionally:
NB.   + A second color (3-vector, color)
NB.   + orientation (3-vector)
NB.
NB. Shape types are encoded as
NB. 0 - plane
NB. 1 - sphere

load 'graphics/png'

NB. For now I'll set up a test scene. We will read this from a JSON
NB. file later
camera =: 0.5 _1 0.5
light =: 0 _0.5 1
ambient =: 0.2
specular =: 0.5
specular_power =: 8
max_reflections =: 6
background =: 135 206 235
image_shape =: 512 512
antialias =: 9
s1 =: 0.7 ; 255 0 0 ; 0.25 0.45 0.4 ; 0.4
s2 =: 0.7 ; 0 255 0 ; 1 1 0.25 ; 0.25
s3 =: 0.7 ; 0 0 255 ; 0.8 0.3 0.15 ; 0.15
spheres =: |: s1 ,. s2 ,. s3
planes =: ,: 0 ; 255 255 255 ; 0 0 0 ; 0 0 1 ; 0 0 0 ; 1 0 0

NB. Dot product and matrix product.
dot =: +/ . *

magnitude =: %: @ dot ~

normalize =: % magnitude

project =: ] * dot % (dot~@])

NB. Get the time index of a collision with a plane. The left
NB. argument is a plane as defined above, the right argument is a
NB. 2x3 array where the first element is a starting point and the
NB. second argument is a direction vector. Returns infinity (_) if
NB. the ray does not intersect the plane.
p_col =: 4 : 0 " 1 2
   p =. > 2 { x
   n =. > 3 { x
   s =. {. y
   v =. {. }. y
   int =. ((dot&(p-s) % dot&v) ` _1: @. (1e_6&>@:|@:dot&v)) n
   int + _ * int<0
)

NB. Get the time index of a collision with a sphere. The arguments
NB. are the same as the plane case above.
s_col =: 4 : 0 " 1 2
   c =. > 2 { x
   r =. > 3 { x
   s =. {. y
   v =. {. }. y
   a =. dot~ v
   b =. 2 * v dot s - c
   c =. (dot~ s-c) - *: r
   d =. (*: b) - 4 * a * c
   int =. (2 * a) %~ (- b) + (%: d) , - %: d
   vs =. ((int"_) ` _: @. <&0) d
   (<./) ((>&0) # ]) _ , vs
)

NB. Get the normal vector for a plane. Since planes have a constant
NB. normal vector, this is a monad.
p_norm =: > @ (3&{)

NB. Get the normal vector for a sphere. The left argument is a
NB. sphere, the right is a point on the surface of the sphere.
s_norm =: (>@(2&{)@[) -~ ]

NB. Get the normal vector for an object. The left argument is the
NB. object type, the right argument is a boxed array containing the
NB. object and the point of intersection.
norm =: (p_norm @ > @ {. @ ]) ` ((>@{.@]) s_norm (>@{.@}.@])) @. [

NB. Get the color of a plane. The right argument is the plane, the
NB. left argument is the point on the plane we need the color of.
p_color =: 4 : 0 " 1 1
   if. 4 < # y
   do.
      o =. > 5 { y
      v =. x - > 2 { y
      a =. v project o
      b =. v - a
      ia =. <. 0.5 + magnitude a
      ib =. <. 0.5 + magnitude b
      (((> 1 { y)"_) ` ((> 4 { y)"_) @. (2&|)) ia + ib
   else. > 1 { y
   end.
)

NB. Get the color of a sphere.
s_color =: > @ {. @ }.

NB. Get the color of an object. The left argument is the type of
NB. the object, the right argument is a boxed array containing
NB. the object itself and the point where the intersection occured.
color =: ((>@{.@}.@]) p_color (>@{.@])) ` (s_color@>@{.@]) @. [

direct_light =: 3 : 0 " 1
   v =. normalize light - y
   t =. v ,:~ y + 1e_6 * v
   pcs =. planes p_col t
   scs =. spheres s_col t
   tp =. <./ pcs
   ts =. <./ scs
   t =. ts <. tp
   t > magnitude light - y
)

NB. Get the color of a ray. The ray is given on the right as a 2x3
NB. array. The left argument is an integer tracking the number of
NB. reflections.
ray_color =: 4 : 0 " 0 2
   NB. Find the intersection points with each object
   pcs =. planes p_col y
   scs =. spheres s_col y
   NB. Figure out which object is nearest and where the
   NB. intersection is
   tpi =. (i.<./) pcs
   tsi =. (i.<./) scs
   NB. tpi and tsi are the indices of the least values in pcs
   NB. and scs. We'll also get the actual minimum values.
   tp =. tpi { pcs
   ts =. tsi { scs
   if. _ = ts <. tp
   do. background
   else.
      NB. We also care about which of these two is the actual
      NB. minimum as well as the point where the intersection
      NB. occurs (c) and the object which was intersected.
      otype =. ts < tp
      t =. (tp"_ ` (ts"_) @. otype) ''
      c =. ({. y) + t * {. }. y
      obj =. ((tpi { planes "_) ` (tsi { spheres "_) @. otype) ''
      n =. normalize otype norm obj ; c
      l =. normalize light - c
      col =. otype color obj ; c
      a =. ambient * 1 - > {. obj
      NB. Calculate reflections only if we haven't reached the
      NB. reflection limit and the reflectivity of the intersected
      NB. object is high enough
      do_refl =. (x < max_reflections) *. 0.003 < > {. obj
      op =. normalize - {. }. y
      ref =. op + 2 * op -~ op project n
      ny =. ref ,:~ c + 1e_6 * ref
      lr =. (0:`(((>:x)"_) ray_color (ny"_))@.do_refl) ''
      lrefl =. (1 - a) * (> {. obj) * lr
      NB. Diffuse lighting
      ldiff =. col * (1 - a) * (1 - >{.obj) * 0 >. n dot l
      NB. Specular lighting
      h =. normalize l + op
      lspec =. 255 255 255*specular*(0>.h dot n)^specular_power
      NB. Ambient lighting
      lamb =. a * col
      NB. Return the sum of the computed colors
      lrefl + lamb + (direct_light c) * ldiff + lspec
   end.
)

NB. Given x and z coordinates on the screen (y = 0) create a ray
NB. coming from the camera and passing through that point.
create_ray =: 3 : 'camera ,: y - camera' " 1

pixel_width =. {. image_shape
pixel_height =. }. image_shape

NB. Create an array of rays for the image.
xvals =. pixel_width %~ i. pixel_width
zvals =. 1 - pixel_width %~ i. pixel_height
points =. zvals (] , 0: , [)"0 0/ xvals
rays =. create_ray points

NB. Find the color of each pixel
colors =: 0 ray_color rays
pixels =: 255 <. <. 0.5 + colors

pixels writepng '/Users/grega/Documents/ray_tracing/j/output.png'