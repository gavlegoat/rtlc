{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Maybe (isJust)
import System.Environment (getArgs)
import Data.Aeson (FromJSON, (.:))
import qualified Data.Aeson as Aeson
import Data.Aeson.Types (Parser)
import Codec.Picture (writePng, generateFoldImage, PixelRGB8(..))
import System.Random (randomRs, initStdGen)

import Types

main :: IO ()
main = do
  args <- getArgs
  if length args /= 2
    then putStrLn "Usage: haskell <scene-description> <output-file>"
    else do
      sc <- Aeson.decodeFileStrict (args !! 0)
      case sc of
        Nothing -> putStrLn "Error decoding scene"
        Just scene -> do
          gen <- initStdGen
          let range = (0.0, 1.0 / fromIntegral (pixelWidth scene))
          writePng (args !! 1) . snd $
            generateFoldImage (pixelColor scene) (randomRs range gen)
                              (pixelWidth scene) (pixelHeight scene)

data Scene = Scene
  { camera :: Point
  , light :: Point
  , ambient :: Double
  , specular :: Double
  , specularPower :: Int
  , maxReflections :: Int
  , background :: Color
  , pixelWidth :: Int
  , pixelHeight :: Int
  , antialias :: Int
  , objects :: [Object]
  }

instance FromJSON Scene where
  parseJSON (Aeson.Object v) = do
    l <- v .: "light"
    c <- v .: "camera"
    a <- v .: "antialias"
    objList <- v .: "objects"
    return $ Scene
      { camera = Point (c !! 0) (c !! 1) (c !! 2)
      , light = Point (l !! 0) (l !! 1) (l !! 2)
      , ambient = 0.2
      , specular = 0.5
      , specularPower = 8
      , maxReflections = 6
      , background = Color 135 206 235
      , pixelWidth = 512
      , pixelHeight = 512
      , antialias = a
      , objects = objList
      }

nearestIntersection :: Scene -> Ray -> Maybe (Object, Double)
nearestIntersection s r = foldr checkIntersection Nothing $ objects s where
  checkIntersection o acc = case collision (shape o) r of
    Nothing -> acc
    Just t -> case acc of
      Nothing -> Just (o, t)
      Just (_, t') -> if t < t' then Just (o, t) else acc

inShadow :: Scene -> Point -> Bool
inShadow s p = isJust $ nearestIntersection s (Ray p (light s ~- p))

rayColor :: Scene -> Ray -> Int -> Color
rayColor s r@(Ray p v) refls = case nearestIntersection s r of
  Nothing -> background s
  Just (o, t) ->
    let col = p ~+ (t ~* v)
        refl = reflectivity o
        amb = ambient s * (1 - refl)
        lAmb = amb ~** getColor o col
        lightDir = normalize $ light s ~- col
        norm = normalize $ normal (shape o) col
        lDiff = (1 - amb) * (1 - refl) * max 0 (norm ~. lightDir) ~**
          getColor o col
        half = normalize $ lightDir <> normalize (vNeg v)
        lSpec = specular s * max 0 (half ~. norm) ^ specularPower s ~**
          Color 255 255 255
        lRefl = if refls < maxReflections s && reflectivity o > 0.003
          then let op = normalize $ vNeg v
                   ref = op <> 2 ~* (project op norm ~-- op)
               in (1 - amb) * refl ~**
                  rayColor s (Ray (col ~+ 1e-5 ~* ref) ref) (refls + 1)
          else Color 0 0 0
    in lAmb <> lRefl <> if inShadow s (col ~+ 1e-6 ~* norm)
                        then Color 0 0 0
                        else lDiff <> lSpec

pointColor :: Scene -> Point -> Color
pointColor s p = rayColor s (Ray p (p ~- camera s)) 0

pixelColor :: Scene -> [Double] -> Int -> Int -> ([Double], PixelRGB8)
pixelColor scene rs i j =
  let (xrs, tl) = splitAt (antialias scene) rs
      (yrs, tl') = splitAt (antialias scene) tl
      cs = zipWith (\xr yr -> pointColor scene $ getPoint i j xr yr) xrs yrs
      Color r g b = 1 / fromIntegral (antialias scene) ~**
        foldr (<>) (Color 0 0 0) cs
  in (tl', PixelRGB8 (clip r) (clip g) (clip b)) where
    getPoint x y r1 r2 =
      Point (fromIntegral x / fromIntegral (pixelWidth scene) + r1)
            0
            (1 - (fromIntegral y / fromIntegral (pixelWidth scene) + r2))
    clip x = fromIntegral $ max 0 (min 255 $ (floor x :: Int))
