module Algorithms.Geometry.UniformPolygonSampling where

import           Algorithms.Geometry.PolygonTriangulation.Triangulate
import           Control.Lens
import           Control.Monad.Random
import           Data.Ext
import           Data.Geometry.Point
import           Data.Geometry.Polygon.Core
import           Data.Geometry.Triangle
import qualified Data.List.NonEmpty                                   as NonEmpty
import           Data.PlaneGraph
import           Data.Proxy
import qualified Data.Vector                                          as V
import           Linear.Affine                                        hiding (Point)
import           Linear.Vector

-- | O(n log n)
samplePolygon :: (RandomGen g, Random r, Fractional r) => Polygon t p r -> Rand g (Point 2 r)
samplePolygon = error "not implemented yet"

-- | O(1)
sampleTriangle :: (RandomGen g, Random r, Fractional r, Ord r) => Triangle 2 p r -> Rand g (Point 2 r)
sampleTriangle (Triangle v1 v2 v3) = do
  a' <- getRandomR (0, 1)
  b' <- getRandomR (0, 1)
  let (a, b) = if a' + b' > 1 then (1 - a', 1 - b') else (a', b')
  return $ v1^.core .+^ a*^u .+^ b*^v
  where
    u = v2^.core .-. v1^.core
    v = v3^.core .-. v1^.core

-- | O(n log n)
toTriangles :: (Fractional r, Ord r) => Polygon t p r -> [Triangle 2 p r]
toTriangles p =
    map (polygonToTriangle . view core . (`rawFacePolygon` g) . fst) $
    V.toList (internalFaces g)
  where
    g = triangulate' Proxy p
    polygonToTriangle poly = case NonEmpty.toList $ polygonVertices poly of
      [v1, v2, v3] -> Triangle v1 v2 v3
      _            -> error "Invalid Triangulation"
