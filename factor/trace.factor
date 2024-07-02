USING:
  accessors
  arrays
  assocs
  byte-arrays
  command-line
  generalizations
  images
  images.loader
  images.ppm
  io
  io.encodings.binary
  io.files
  json
  kernel
  lists
  math
  math.functions
  math.order
  math.vectors
  namespaces
  prettyprint
  random
  sequences
  vectors
  ;
IN: trace

: dropd ( x y -- y ) swap drop ;

! project u onto v: w = ((u . v) / (v . v)) v
!                     ( u v -- u v v )   dup
!           ( u v v -- (v.u) (v.v) v )   [ [ vdot ] [ dropd norm-sq ] 2bi ] dip
! ( (v.u) (v.v) v -- ((v.u)/(v.v)) v )   [ / ] dip
!            ( u ((v.u)/(u .u)) -- w )   n*v
: project ( u v -- w ) dup [ [ vdot ] [ dropd norm-sq ] 2bi / ] dip n*v ;

: randf ( -- r ) 32 random-bits >float 2 32 ^ / ;


! =====================
! = Shape definitions =
! =====================

MIXIN: shape

! Shapes interface
GENERIC: get-reflectivity ( shape -- refl )
GENERIC: get-color ( point shape -- color )
GENERIC: get-normal ( point shape -- vector )
GENERIC: get-collision-time ( point vector shape -- time )

TUPLE: sphere
  { reflectivity real read-only }
  { color sequence read-only }
  { center sequence read-only }
  { radius real read-only } ;

: <sphere> ( refl color center radius -- sphere ) sphere boa ;

INSTANCE: sphere shape

M: sphere get-color [ drop ] dip color>> ;

M: sphere get-normal center>> v- ;

! Shere get-collision-time
!   let a = norm-sq dir
!   let v = start - sphere.center
!   let b = 2 * dir dot v
!   let c = norm-sq v - sphere.radius^2
!   let discr = b * b - 4 * a * c
!   if discr < 0: return -1
!   let t1 = (-b + sqrt discr) / (2 * a)
!   let t2 = (-b - sqrt discr) / (2 * a)
!   if t1 < 0 then t2 else if t2 < 0 then t1 else min t1 t2
! The helper computes t from ( 2a b discr ) assuming discr is non-negative
! ( 2a b discr -- n1 n2 2a )   sqrt [ neg ] dip [ + ] [ - ] 2bi rot
!      ( n1 n2 2a -- t1 t2 )   [ / ] keep swapd /
!          ( t1 t2 -- time )   dup 0 < [ drop ] [ swap dup 0 < [ drop ] [ min ] if ] if
: sphere-col-help ( 2a b discr -- time )
    sqrt [ neg ] dip [ + ] [ - ] 2bi rot
    [ / ] keep swapd /
    dup 0 < [ drop ] [ swap dup 0 < [ drop ] [ min ] if ] if ;

! Sphere collision time main word
! ( start dir sphere -- a start dir sphere )   [ dup norm-sq ] dip -rotd
!   ( a start dir sphere -- a dir v sphere )   swapd dup [ center>> v- ] dip
!         ( a dir v sphere -- a sphere b v )   -rot dup [ vdot 2 * ] dip
!                  ( a sphere b v -- a b c )   norm-sq rot radius>> sq -
!                   ( a b c -- 2a 4ac b b2 )   swap [ [ 2 * dup ] dip * 2 * ] [ dup sq ] bi*
!              ( 2a 4ac b b2 -- 2a b discr )   rot -
!                     ( 2a b discr -- time )   dup 0 < [ 3drop -1 ] [ sphere-col-help ] if
M: sphere get-collision-time
    [ dup norm-sq ] dip -rotd
    swapd dup [ center>> v- ] dip
    -rot dup [ vdot 2 * ] dip
    norm-sq rot radius>> sq -
    swap [ [ 2 * dup ] dip * 2 * ] [ dup sq ] bi*
    rot -
    dup 0 < [ 3drop -1 ] [ sphere-col-help ] if ;

TUPLE: plane
  { reflectivity real read-only }
  { color sequence read-only }
  { point sequence read-only }
  { normal sequence read-only }
  { checkerboard boolean read-only }
  { check-color sequence read-only }
  { orientation sequence read-only } ;

: <plane> ( refl color pt norm check ch-color ori -- plane ) plane boa ;

INSTANCE: plane shape

! Get the color of a checkerboard plane
!   let v = plane.point - point
!   let x = project v plane.orientation,
!   let y = v - x
!   if (round(norm(x)) + round(norm(y))) % 2 == 0 then check-color else color
!        ( point plane -- plane v )   swap [ dup point>> ] dip v-
!        ( plane v -- plane ori v )   [ dup orientation>> ] dip
!  ( plane ori v -- plane v_ori v )   dup [ project ] dip
!    ( plane v_ori v -- plane x y )   [ dup ] dip swap v-
!      ( plane x y -- plane ix iy )   [ norm round >integer ] bi@
! ( plane ix iy -- plane in-check )   + even?
!       ( plane in-check -- color )   [ color>> ] [ check-color>> ] if
: plane-check ( plane point -- color )
    swap [ dup point>> ] dip v- [ dup orientation>> ] dip dup [ swap project ] dip
    [ dup ] dip swap v- [ norm round >integer ] bi@ + even?
    [ color>> ] [ check-color>> ] if ;

! Get the color of a point on a plane.
! if plane.checkerboard then call plane-check, otherwise return color.
M: plane get-color
    dup checkerboard>> [ plane-check ] [ dropd color>> ] if ;

M: plane get-normal [ drop ] dip normal>> ;

! Get collision time for a plane.
!   let a = plane.normal dot dir
!   if abs(a) < 1e-6: return f
!   let t = (plane.point - start) dot normal / a
!   if t < 0 then f else t
! Helper function handles the normal case where a is not close to zero.
! ( start plane a -- a start point normal )   -rot dup [ point>> ] dip normal>>
!          ( a start point normal -- time )   -rot swap v- vdot swap /
: plane-col ( start plane a -- time ) -rot dup [ point>> ] dip normal>>
    -rot swap v- vdot swap / ;

! Main function for plane collision time.
!    ( start dir plane -- start plane a )   dup normal>> rot vdot
! ( start plane a -- start plane a test )   dup abs 1e-6 <
!          ( start plane a test -- time )   [ 3drop f ] [ plane-col ] if
M: plane get-collision-time dup normal>> rot vdot dup abs 1e-6 <
    [ 3drop -1 ] [ plane-col ] if ;

M: shape get-reflectivity reflectivity>> ;


! ====================
! = Scene definition =
! ====================

TUPLE: scene
  { ambient real read-only }
  { specular real read-only }
  { specular-power real read-only }
  { max-reflections integer read-only }
  { background sequence read-only }
  { light sequence read-only }
  { camera sequence read-only }
  { objects vector } ;

: <scene> ( light camera -- scene )
    [ 0.2 0.5 8 6 { 135 206 235 } ] 2dip V{ } clone scene boa ;

: add-object ( obj scene -- ) objects>> push ;

! If the second element of y is both positive and less than x, leave y
! otherwise leave x.
: min-pos ( x y -- z )
    [ first2 ] bi@ swapd [ dup ] bi@ -rot
    > [ dup 0 > ] dip and rot dup 0 < swapd or swapd
    [ [ drop [ drop ] dip ] dip ] [ drop [ drop ] dip ] if 2array ;

! Find the minimum positive element in a list of items
: min-positive-time ( objs times -- obj time )
    zip 0 over nth [ >list ] dip [ min-pos ] foldl first2 ;

! Get the time and object of the nearest intersection for a ray in the scene.
: nearest-int ( start dir scene -- obj time )
    objects>> dup -rotd [ [ 2dup ] dip get-collision-time ] map
    [ 2drop ] dip min-positive-time ;

! =================
! = Coloring code =
! =================

DEFER: color-ray

! Push a point slightly away from a surface
: offset ( dir pt -- dir npt ) over 1e-6 v*n v+ ;

! Get ambient lighting
: ambient ( scene obj col dir -- color )
    drop swap get-color swap ambient>> v*n ;

! Get the direction from a point to a scene's light source
: light-dir ( pt scene -- dir ) light>> swap v- normalize ;


! Compute diffuse lighting.
! ( scene obj col norm -- scene obj col norm light-dir )   over 5 npick light-dir
! ( scene obj col norm light-dir -- scene obj col fact 1-refl )
!   vdot 0 max pick get-reflectivity 1 swap -
! ( scene obj col fact 1-refl -- obj col fact )
!   5 nrot ambient>> 1 swap - * *
! ( obj fact col -- color )   rot get-color n*v
: diffuse ( scene obj col norm -- color )
    over 5 npick light-dir vdot 0 max pick get-reflectivity 1 swap -
    5 nrot ambient>> 1 swap - * *
    -rot swap get-color n*v ;

! Compute specular lighting.
! ( scene obj col norm dir -- scene norm dir light-dir )
!    [ drop ] 3dip rot 4 npick light-dir
! ( scene norm dir light-dir -- scene norm half )
!    swap vneg normalize v+ normalize
! ( scene norm half -- scene fact )   vdot 0 max
! ( scene fact -- fact spec spec_pow )
!    swap [ specular>> ] [ specular-power>> ] bi
! ( fact spec spec_pow -- color )
!    swapd ^ * { 255 255 255 } n*v
: specular ( scene obj col norm dir -- color )
    [ drop ] 3dip rot 4 npick light-dir
    swap vneg normalize v+ normalize vdot 0 max
    swap [ specular>> ] [ specular-power>> ] bi
    swapd ^ * { 255 255 255 } n*v ;

! Get diffuse and specular lighting if the object is unshaded.
! ( scene obj col dir -- scene obj col dir norm light-dir )
!    2over swap get-normal pick 6 npick light-dir
! ( scene obj col dir norm light-dir -- scene obj col norm dir in-shadow )
!    4 npick offset swap 7 npick nearest-int dropd 0 > swapd
: direct ( scene obj col dir -- color )
    2over swap get-normal normalize pick 6 npick light-dir
    4 npick offset swap 7 npick nearest-int dropd 0 > swapd
    [ 5drop { 0 0 0 } ] [ [ drop diffuse ] 5 nkeep specular v+ ] if ;

! Get the direction of a reflection vector.
: refl-dir ( op norm -- ref ) 2dup project swapd dupd swap v- 2 v*n v+ dropd ;

! Get reflected lighting
! ( refls scene obj col dir -- refls scene op col obj ) vneg normalize -rot swap
! ( refls scene op col obj -- refls scene col op refl norm )
!   [ swap over ] dip [ dropd get-reflectivity ] [ get-normal ] 2bi
! ( refls scene col op refl norm -- refls scene refl pt dir )
!   swapd refl-dir rot offset swap
! ( refls scene refl pt dir -- refl c2 ) [ rot 1 + rot ] 2dip rot color-ray
! ( refl c2 -- color ) n*v
: reflected ( refls scene obj col dir -- color )
    vneg normalize -rot swap
    [ swap over ] dip [ dropd get-reflectivity ] [ get-normal ] 2bi
    swapd refl-dir rot offset swap
    [ rot 1 + rot ] 2dip rot color-ray
    n*v ;

! Get the color of lighting along a ray given the object it first intersects.
! ( refls start dir scene obj time -- refls scene obj start dir time )
!   5 nrot 5 nrot rot
! ( refls scene obj start dir time -- refls scene obj col dir )
!   over n*v swapd v+ swap
: lighting ( refls start dir scene obj time -- color )
    5 nrot 5 nrot rot over n*v swapd v+ swap
    [ direct ] 4keep
    [ ambient ] 4keep
    [ rot ] 4dip reflected
    v+ v+ ;

! Get the color of lighting along a ray
! ( refls start dir scene -- color )
: color-ray-help ( refls start dir scene -- color )
    3dup nearest-int dup 0 <
    [ 2drop [ 3drop ] dip background>> ] [ lighting ] if ;

: color-ray ( refls start dir scene -- color )
    dup max-reflections>> 5 nrot dup swapd <
    [ 4drop { 0 0 0 } ] [ 4 -nrot color-ray-help ] if ;

: color-point ( pt scene -- color )
    dup camera>> swapd dupd v- 0 4 -nrot rot color-ray ;

: color-pixel-sample ( scene scale x y -- color )
    [ randf + ] bi@ rot dup swapd [ / ] 2bi@ 1 swap - 0 swap 3array swap color-point ;

! ( scene scale aa x y -- scene scale x y c aa seq )   { 0 0 0 } 4 nrot dup <iota>
! ( scene scale x y c aa seq -- aa c scene scale x y seq )   [ 6 -nrot 5 -nrot ] dip
! Loop body: ( aa c scene scale x y seq -- aa c scene scale x y )
!                  drop 4dup color-pixel-sample 6 nrot v+ 5 -nrot
! ( aa c scene scale x y seq -- aa c )   [ (loop body) ] each 4drop
! ( aa c -- color )   swap v/n
: color-pixel ( scene scale antialias x y -- color )
    { 0 0 0 } 4 nrot dup <iota> [ 6 -nrot 5 -nrot ] dip
    [ drop 4dup color-pixel-sample 6 nrot v+ 5 -nrot ] each 4drop swap v/n ;


! ================
! = JSON Parsing =
! ================

: json>sphere ( refl col json-obj -- sphere )
    [ "center" of ] [ "radius" of ] bi <sphere> ;

: json>plane ( refl col json-obj -- sphere )
    dup [ [ "point" of ] [ "normal" of ] [ "checkerboard" of ] tri ] dip swap
    [ swap [ "color2" of ] [ "orientation" of ] bi <plane> ]
    [ drop f { 0 0 0 } { 0 0 0 } <plane> ]
    if* ;

: json>object ( json-obj -- object )
    dup [ "reflectivity" of ] [ "color" of ] bi rot
    dup "type" of "sphere" = [ json>sphere ] [ json>plane ] if ;

: add-one-object ( scene json-obj -- )
    json>object swap add-object ;

: add-all-objects ( scene json -- )
    "objects" of [ dupd add-one-object ] each drop ;

: json>scene ( json -- antialias scene )
    dup "antialias" of swap
    dup [ "light" of ] [ "camera" of ] bi
    <scene> swap dupd add-all-objects ;

: path>scene ( path -- antialias scene ) path>json json>scene ;


! =============
! = Main code =
! =============

! Create a new all-black image with the given width and height
: blank-image ( w h -- image )
    2dup 2array -rot 3 * * [ RGB ubyte-components f t ] dip
    <byte-array> f image boa ;

: convert-color ( color -- bcolor )
    [ 0.5 + >integer 0 max 255 min ] map >byte-array ;

: set-pixel ( image scene scale anti x y -- )
    2dup [ color-pixel convert-color ] 2dip 4 nrot set-pixel-at ;

! ( config-path output-path -- output-path scene antialias ) swap path>scene
! ( out scene anti -- out scene scale anti image ) 512 dup swapd 512 blank-image
! ( out scene scale anti image -- out image )
!    [ drop [ 4drop ] 2dip set-pixel ] each-pixel 3drop
! ( out image -- ) swap save-graphic-image
: main ( config-path output-path -- )
    swap path>scene swap
    512 dup swapd 512 blank-image
    dup 5 -nrot
    [ drop [ 4dup ] 2dip set-pixel ] each-pixel 3drop
    swap "ppm" ppm-image rot binary [ image>stream ] with-file-writer ;

command-line get dup length 2 = [
    first2 main
] [
    drop "Usage: factor trace.factor <config-file> <output-file>" print
] if
