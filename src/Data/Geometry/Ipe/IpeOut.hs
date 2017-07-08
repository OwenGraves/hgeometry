{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Data.Geometry.Ipe.IpeOut where

import           Control.Lens hiding (Simple)
import           Data.Bifunctor
import           Data.Ext
import           Data.Geometry.Ball
import           Data.Geometry.Boundary
import           Data.Geometry.Box
import           Data.Geometry.Ipe.Attributes
import           Data.Geometry.Ipe.FromIpe
import           Data.Geometry.Ipe.Types
import           Data.Geometry.Line
import           Data.Geometry.LineSegment
import           Data.Geometry.Point
import           Data.Geometry.PolyLine
import           Data.Geometry.Polygon
import           Data.Geometry.Polygon.Convex
import           Data.Geometry.Properties
import           Data.Geometry.Transformation
import           Data.Maybe (fromMaybe)
import           Data.Proxy
import           Data.Semigroup
import qualified Data.Seq2 as S2
import           Data.Text (Text)
import           Frames.CoRec

--------------------------------------------------------------------------------

-- | An IpeOut is essentially a funciton to convert a geometry object of type
-- 'g' into an ipe object of type 'i'.
newtype IpeOut g i = IpeOut { asIpe :: g -> i } deriving (Functor)


-- | Given an geometry object, and a record with its attributes, construct an ipe
-- Object representing it using the default conversion.
asIpeObject :: (HasDefaultIpeOut g, DefaultIpeOut g ~ i, NumType g ~ r)
            => g -> IpeAttributes i r -> IpeObject r
asIpeObject = asIpeObjectWith defaultIpeOut

-- | asIpeObject with its arguments flipped. Convenient if you don't want to
-- map asIpeObject over a list or so.
asIpeObject' :: (HasDefaultIpeOut g, DefaultIpeOut g ~ i, NumType g ~ r)
             => IpeAttributes i r -> g -> IpeObject r
asIpeObject' = flip asIpeObject


-- -- | Given a IpeOut that specifies how to convert a geometry object into an
-- ipe geometry object, the geometry object, and a record with its attributes,
-- construct an ipe Object representing it.
asIpeObjectWith          :: (ToObject i, NumType g ~ r)
                         => IpeOut g (IpeObject' i r) -> g -> IpeAttributes i r
                         -> IpeObject r
asIpeObjectWith io g ats = asIpe (ipeObject io ats) g


-- | Create an ipe group without group attributes
asIpeGroup :: [IpeObject r] -> IpeObject r
asIpeGroup = flip asIpeGroup' mempty

-- | Creates a group out of ipe
asIpeGroup'        :: [IpeObject r] -> IpeAttributes Group r -> IpeObject r
asIpeGroup' gs ats = IpeGroup $ Group gs :+ ats

--------------------------------------------------------------------------------

-- | Helper to construct an IpeOut g IpeObject , if we already know how to
-- construct a specific Ipe type.
ipeObject        :: (ToObject i, NumType g ~ r)
                   => IpeOut g (IpeObject' i r) -> IpeAttributes i r -> IpeOut g (IpeObject r)
ipeObject io ats = IpeOut $ \g -> let (i :+ ats') = asIpe io g
                                    in ipeObject' i (ats' <> ats)

-- | Construct an ipe object from the core of an Ext
coreOut    :: IpeOut g i -> IpeOut (g :+ a) i
coreOut io = IpeOut $ asIpe io . (^.core)

--------------------------------------------------------------------------------
-- * Default Conversions

-- | Class that specifies a default conversion from a geometry type g into an
-- ipe object.
class ToObject (DefaultIpeOut g) => HasDefaultIpeOut g where
  type DefaultIpeOut g :: * -> *

  defaultIpeOut :: IpeOut g (IpeObject' (DefaultIpeOut g) (NumType g))

  -- defaultIpeObject :: RecApplicative (AttributesOf (DefaultIpeOut g))
  --                  => IpeOut g (IpeObject (NumType g))
  -- defaultIpeObject = IpeOut $ flip asIpeObject mempty

instance HasDefaultIpeOut (Point 2 r) where
  type DefaultIpeOut (Point 2 r) = IpeSymbol
  defaultIpeOut = ipeDiskMark

instance HasDefaultIpeOut (LineSegment 2 p r) where
  type DefaultIpeOut (LineSegment 2 p r) = Path
  defaultIpeOut = ipeLineSegment

instance Floating r => HasDefaultIpeOut (Disk p r) where
  type DefaultIpeOut (Disk p r) = Path
  defaultIpeOut = ipeDisk

instance HasDefaultIpeOut (PolyLine 2 p r) where
  type DefaultIpeOut (PolyLine 2 p r) = Path
  defaultIpeOut = noAttrs ipePolyLine

instance HasDefaultIpeOut (SimplePolygon p r) where
  type DefaultIpeOut (SimplePolygon p r) = Path
  defaultIpeOut = flip addAttributes ipePolygon $
                    mempty <> attr SFill (IpeColor "0.722 0.145 0.137")

instance HasDefaultIpeOut (MultiPolygon p r) where
  type DefaultIpeOut (MultiPolygon p r) = Path
  defaultIpeOut = flip addAttributes ipePolygon $
                    mempty <> attr SFill (IpeColor "0.722 0.145 0.137")

instance HasDefaultIpeOut (ConvexPolygon p r) where
  type DefaultIpeOut (ConvexPolygon p r) = Path
  defaultIpeOut = IpeOut $ asIpe defaultIpeOut . view simplePolygon

--------------------------------------------------------------------------------
-- * Point Converters

ipeMark   :: Text -> IpeOut (Point 2 r) (IpeObject' IpeSymbol r)
ipeMark n = noAttrs . IpeOut $ flip Symbol n

ipeDiskMark :: IpeOut (Point 2 r) (IpeObject' IpeSymbol r)
ipeDiskMark = ipeMark "mark/disk(sx)"

--------------------------------------------------------------------------------

noAttrs :: Monoid extra => IpeOut g core -> IpeOut g (core :+ extra)
noAttrs = addAttributes mempty

addAttributes :: extra -> IpeOut g core -> IpeOut g (core :+ extra)
addAttributes ats io = IpeOut $ \g -> asIpe io g :+ ats


-- | Default size of the cliping rectangle used to clip lines. This is
-- Rectangle is large enough to cover the normal page size in ipe.
defaultClipRectangle :: (Num r, Ord r) => Rectangle () r
defaultClipRectangle = boundingBox (point2 (-200) (-200)) <>
                       boundingBox (point2 1000 1000)

-- | An ipe out to draw a line, by clipping it to stay within a rectangle of
-- default size.
line :: (Fractional r, Ord r) => IpeOut (Line 2 r) (IpeObject' Path r)
line = lineWith defaultClipRectangle

-- | An ipe out to draw a line, by clipping it to stay within the rectangle.
--
-- pre: intersection of the line and the rectangle is a line segment
-- (otherwise it arbitrarily inserts the bottom of the rectangle as the path)
lineWith   :: forall p r. (Ord r, Fractional r)
              => Rectangle p r -> IpeOut (Line 2 r) (IpeObject' Path r)
lineWith r = IpeOut (asIpe defaultIpeOut . clip)
  where
    def    = bimap (const ()) id $ bottomSide r
    clip l = fromMaybe def . asA (Proxy :: Proxy (LineSegment 2 () r))
           $ l `intersect` r

ipeLineSegment :: IpeOut (LineSegment 2 p r) (IpeObject' Path r)
ipeLineSegment = noAttrs $ fromPathSegment ipeLineSegment'

ipeLineSegment' :: IpeOut (LineSegment 2 p r) (PathSegment r)
ipeLineSegment' = IpeOut $ PolyLineSegment . fromLineSegment . first (const ())


ipePolyLine :: IpeOut (PolyLine 2 p r) (Path r)
ipePolyLine = fromPathSegment ipePolyLine'

ipePolyLine' :: IpeOut (PolyLine 2 a r) (PathSegment r)
ipePolyLine' = IpeOut $ PolyLineSegment . first (const ())

ipeDisk :: Floating r => IpeOut (Disk p r) (IpeObject' Path r)
ipeDisk = noAttrs . IpeOut $ asIpe ipeCircle . Boundary

ipeCircle :: Floating r => IpeOut (Circle p r) (Path r)
ipeCircle = fromPathSegment ipeCircle'

ipeCircle' :: Floating r => IpeOut (Circle p r) (PathSegment r)
ipeCircle' = IpeOut circle''
  where
    circle'' (Circle (c :+ _) r) = EllipseSegment m
      where
        m = translation (toVec c) |.| uniformScaling (sqrt r) ^. transformationMatrix
        -- m is the matrix s.t. if we apply m to the unit circle centered at the origin, we
        -- get the input circle.


-- | Helper to construct a IpeOut g Path, for when we already have an IpeOut g PathSegment
fromPathSegment    :: IpeOut g (PathSegment r) -> IpeOut g (Path r)
fromPathSegment io = IpeOut $ Path . S2.l1Singleton . asIpe io


ipePolygon :: IpeOut (Polygon t p r) (Path r)
ipePolygon = IpeOut $ io . first (const ())
  where
    io                       :: forall t r. Polygon t () r -> Path r
    io pg@(SimplePolygon vs) = pg^.re _asSimplePolygon
    io pg@(MultiPolygon _ _) = pg^.re _asMultiPolygon









-- ls = (ClosedLineSegment (ext origin) (ext (point2 1 1)))


-- testzz :: IpeObject Integer
-- testzz = asIpeObjectWith ipeLineSegment ls $ mempty <> attr SStroke (IpeColor "red")




-- test' :: Attributes (PathAttrElfSym1 Integer) (AttributesOf (Path Integer) (PathAttrElfSym1 Integer))
-- -- test' :: RecApplicative (AttributesOf (Path Integer) (IpeObjectSymbolF (Path Integer)))
-- --       => IpeAttributes (Path Integer)
-- test' = mempty




-- -- test' :: IpeObject Integer ('IpePath '[])
-- test' = asIpeObject' ls emptyPathAttributes




-- emptyPathAttributes :: Rec (PathAttribute r) '[]
-- emptyPathAttributes = RNil
