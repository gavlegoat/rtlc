{-# LANGUAGE OverloadedStrings #-}

module Types
  ( Vector(..)
  , (~.)
  , (~#)
  , (~*)
  , (~**)
  , (~-)
  , (~--)
  , (~+)
  , vNeg
  , normalize
  , project
  , Point(..)
  , Color(..)
  , Ray(..)
  , collision
  , normal
  , Shape(..)
  , Object(..)
  , getColor
  ) where

import Data.Aeson (FromJSON, (.:))
import qualified Data.Aeson as Aeson
import Data.Aeson.Types (Parser)

data Vector = Vector Double Double Double deriving (Show)

(~.) :: Vector -> Vector -> Double
Vector ax ay az ~. Vector bx by bz = ax * bx + ay * by + az * bz

infixl 7 ~.

(~#) :: Vector -> Vector -> Vector
Vector ax ay az ~# Vector bx by bz =
  Vector (ay * bz - az * by) (ax * bz - az * bx) (ax * by - ay * bx)

infixl 7 ~#

(~*) :: Double -> Vector -> Vector
a ~* Vector x y z = Vector (a * x) (a * y) (a * z)

infixl 7 ~*

(~--) :: Vector -> Vector -> Vector
Vector ax ay az ~-- Vector bx by bz = Vector (ax - bx) (ay - by) (az - bz)

infixl 6 ~--

vNeg :: Vector -> Vector
vNeg (Vector x y z) = Vector (- x) (- y) (- z)

magnitude :: Vector -> Double
magnitude v = sqrt (v ~. v)

normalize :: Vector -> Vector
normalize v = 1 / magnitude v ~* v

project :: Vector -> Vector -> Vector
project a b = (a ~. b) / (b ~. b) ~* b

instance Semigroup Vector where
  (Vector ax ay az) <> (Vector bx by bz) = Vector (ax + bx) (ay + by) (az + bz)

instance Monoid Vector where
  mempty = Vector 0.0 0.0 0.0

data Point = Point Double Double Double deriving (Show)

(~-) :: Point -> Point -> Vector
Point ax ay az ~- Point bx by bz = Vector (ax - bx) (ay - by) (az - bz)

infixl 6 ~-

(~+) :: Point -> Vector -> Point
Point ax ay az ~+ Vector bx by bz = Point (ax + bx) (ay + by) (az + bz)

infixl 6 ~+

data Color = Color Double Double Double deriving (Show)

instance Semigroup Color where
  (Color ar ag ab) <> (Color br bg bb) = Color (ar + br) (ag + bg) (ab + bb)

(~**) :: Double -> Color -> Color
a ~** Color r g b = Color (a * r) (a * g) (a * b)

infixl 6 ~**

instance Monoid Color where
  mempty = Color 0.0 0.0 0.0

data Ray = Ray
  { rayStart :: Point
  , rayDirection :: Vector
  }

data Shape
  = Sphere { sphereCenter :: Point, sphereRadius :: Double }
  | Plane { planePoint :: Point
          , planeNormal :: Vector
          , color2 :: Maybe Color
          , orientation :: Maybe Vector }

collision :: Shape -> Ray -> Maybe Double
collision (Sphere cen r) (Ray p v) =
  let a = v ~. v
      v' = p ~- cen
      b = 2 * (v ~. v')
      c = v' ~. v' - r * r
      d = b * b - 4 * a * c
  in if d < 0 then Nothing else
    let t1 = (-b + sqrt d) / (2 * a)
        t2 = (-b - sqrt d) / (2 * a)
    in if t1 < 0
    then if t2 < 0 then Nothing else Just t2
    else if t2 < 0 then Just t1 else Just (min t1 t2)
collision (Plane o n _ _) (Ray p v) =
  if abs (n ~. v) < 1e-6
  then Nothing
  else let t = n ~. (o ~- p) / (v ~. n) in
    if t < 0 then Nothing else Just t

normal :: Shape -> Point -> Vector
normal (Sphere c _) p = p ~- c
normal (Plane _ n _ _) _ = n

data Object = Object
  { color :: Color
  , reflectivity :: Double
  , shape :: Shape
  }

getColor :: Object -> Point -> Color
getColor o pt = case shape o of
  Sphere{} -> color o
  Plane p _ c ori -> case (c, ori) of
    (Nothing, Nothing) -> color o
    (Just c2, Just ori) ->
      let v = pt ~- p
          x = project v ori
          y = v ~-- x
          ix = floor (magnitude x + 0.5)
          iy = floor (magnitude y + 0.5)
      in if even (ix + iy) then color o else c2
    _ -> error "Illegal combination of data in Plane"

instance FromJSON Object where
  parseJSON (Aeson.Object v) = do
    c <- v .: "color"
    r <- v .: "reflectivity"
    t <- (v .: "type") :: Parser String
    if t == "sphere"
      then do
        cen <- v .: "center"
        rad <- v .: "radius"
        return $ Object
          { color = Color (c !! 0) (c !! 1) (c !! 2)
          , reflectivity = r
          , shape = Sphere
            { sphereCenter = Point (cen !! 0) (cen !! 1) (cen !! 2)
            , sphereRadius = rad
            }
          }
        else do
          p <- v .: "point"
          n <- v .: "normal"
          ch <- v .: "checkerboard"
          if ch
            then do
              c2 <- v .: "color2"
              ori <- v .: "orientation"
              return $ Object
                { color = Color (c !! 0) (c !! 1) (c !! 2)
                , reflectivity = r
                , shape = Plane
                  { planePoint = Point (p !! 0) (p !! 1) (p !! 2)
                  , planeNormal = Vector (n !! 0) (n !! 1) (n !! 2)
                  , color2 = Just $ Color (c2 !! 0) (c2 !! 1) (c2 !! 2)
                  , orientation = Just $ Vector (ori !! 0) (ori !! 1) (ori !! 2)
                  }
                }
            else return $ Object
              { color = Color (c !! 0) (c !! 1) (c !! 2)
              , reflectivity = r
              , shape = Plane
                { planePoint = Point (p !! 0) (p !! 1) (p !! 2)
                , planeNormal = Vector (n !! 0) (n !! 1) (n !! 2)
                , color2 = Nothing
                , orientation = Nothing
                }
              }
