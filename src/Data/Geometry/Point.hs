{-# LANGUAGE UndecidableInstances #-}    -- Def R1

{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE RankNTypes #-} --  lens stuff


{-# LANGUAGE PolyKinds #-}     --- TODO: Why do we need this?

{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}

module Data.Geometry.Point( --Point(..)
                          -- , point

                          ) where

-- import Control.Applicative
import Control.Lens(Lens')




import Linear.Affine hiding (Point(..))
import Linear.Vector

import Data.Maybe
import Data.Proxy

import Data.Geometry.Properties
-- import Data.Geometry.Vector


import Data.Vector.Fixed.Boxed
import Data.Vector.Fixed.Cont
import Data.Vector.Fixed

import Data.Vinyl
import Data.Vinyl.Idiom.Identity
import Data.Vinyl.TyFun
import Data.Vinyl.Lens
import Data.Vinyl.Universe.Geometry


import Data.Type.Nat

import GHC.TypeLits

import qualified Data.Vector.Fixed as V

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- | A defintition of a d dimentional space

-- | R d is a type level list containing all DFields for dimensions 1 t/m d
-- type R (d :: Nat) = R1 (ToNat1 d)
type R (d :: Nat) = Range 1 d

type R1 (d :: Nat1) = Range1 (Succ Zero) d

-- | Type level list concatenation
type family (xs :: [k]) ++ (ys :: [k]) :: [k] where
  '[] ++ ys       = ys
  (x ': xs) ++ ys = x ': (xs ++ ys)

infixr 5 ++


type Range (s :: Nat) (k :: Nat) = Range1 (ToNat1 s) (ToNat1 k)


type family Range1 (s :: Nat1) (k :: Nat1) where
  Range1 s Zero     = '[]
  Range1 s (Succ k) = DField (FromNat1 s) ': Range1 (Succ s) k

--------------------------------------------------------------------------------
-- | Conversion from Point to Vector

type family Len (xs :: [*]) where
  Len '[]       = Z
  Len (x ': xs) = S (Len xs)

class ToContVec (rs :: [*]) where
  toContVec :: PlainTRec r rs -> ContVec (Len rs) r

instance ToContVec '[] where
  toContVec _ = empty

instance ToContVec rs => ToContVec (DField i ': rs) where
  toContVec (r :& rs) = runIdentity r <| toContVec rs


toVec              :: forall d r fs. ( Len (R d) ~ ToPeano d
                                     , ToContVec (R d)
                                     , Arity (ToPeano d)
                                     ) =>
                      Point d r fs -> Vec (ToPeano d) r
toVec (Point g _) = vector $ toContVec g


--------------------------------------------------------------------------------
-- | Conversion from Vector to Point


type family PeanoToNat1 (n :: *) :: Nat1 where
  PeanoToNat1 Z = Zero
  PeanoToNat1 (S n) = Succ (PeanoToNat1 n)

type family Nat1ToPeano (n :: Nat1) :: * where
  Nat1ToPeano Zero     = Z
  Nat1ToPeano (Succ n) = S (Nat1ToPeano n)

----------------------------------------

-- | Wrapper around Vec that converts from their Peano numbers to Our peano numbers
data Vector' (d :: Nat1) (r :: *) where
  Vector' :: Vec (Nat1ToPeano d) r -> Vector' d r


destr             :: Arity (Nat1ToPeano d) => Vector' (Succ d) r -> (r, Vector' d r)
destr (Vector' v) = (V.head v,Vector' $ V.tail v)

----------------------------------------

class Directly (d :: Nat1) where
  vecToRec :: Proxy s -> Proxy d -> Vector' d r -> PlainTRec r (Range1 s d)

instance Directly Zero where
  vecToRec _ _ _ = RNil

instance (Arity (Nat1ToPeano d), Directly d) => Directly (Succ d) where
  vecToRec (_ :: Proxy s) _ v = let (x,xs) = destr v in
                                (Identity x)
                                :&
                                vecToRec (Proxy :: Proxy (Succ s)) (Proxy :: Proxy d) xs



-- | Version of vecToRec without the proxies
vecToRec' :: forall d d1 r. ( Directly d1
                            , FromNat1 d1 ~ d, ToNat1 d ~ d1
                            )
                            => Vector' d1 r -> PlainTRec r (R d)
vecToRec' = vecToRec (Proxy :: Proxy (ToNat1 1)) (Proxy :: Proxy d1)


toPoint   :: forall d1 d r. ( Directly d1
                            , FromNat1 d1 ~ d, ToNat1 d ~ d1
                            )
                            => Vector' d1 r -> Point d r '[]
toPoint = flip Point RNil . vecToRec'






-- myVect :: Vector' (Succ (Succ (Succ Zero))) Int
myVect :: Vector' (ToNat1 3) Int
myVect = Vector' vect


vect :: Vec (ToPeano 3) Int
vect = V.mk3 1 2 3




myXX = toPoint myVect







--------------------------------------------------------------------------------
-- | Constructing a point from a monolithic PlainTRec


class Split (xs :: [*]) (ys :: [*]) where
  splitRec :: Rec el f (xs ++ ys) -> (Rec el f xs, Rec el f ys)

instance Split '[] ys where
  splitRec r = (RNil,r)

instance Split xs ys => Split (x ': xs) ys where
  splitRec (r :& rs) = let (rx,ry) = splitRec rs
                       in (r :& rx, ry)


sp :: (PlainTRec Int '[DField 1], PlainTRec Int '["name" :~>: String])
sp = splitRec pt

--------------------------------------------------------------------------------
-- | Points in a d-dimensional space

-- | A Point in a d dimensional space. Apart from coordinates in R^d may have
-- additonal fields/attributes. For example color, a label, etc.
data Point (d :: Nat) (r :: *) (fields :: [*]) where
  Point :: PlainTRec r (R d) -> PlainTRec r fields -> Point d r fields


-- | Smart constructor that allows a different order of the input fields
point :: forall d r fields allFields.
          ( Split (R d) fields
          , allFields :~: (R d ++ fields)
          ) => PlainTRec r allFields -> Point d r fields
point = uncurry Point . splitRec . cast


--------------------------------------------------------------------------------
-- | Some common fields

-- | Some hands for the axis (fields) in the first three dimensions
x = SNatField :: SDField 1
y = SNatField :: SDField 2
z = SNatField :: SDField 3

-- | And a regular named field
name :: SSField "name" String --SField (Field ("name" ::: String))
name = SSymField


----------------------------------------
 -- bar :: Functor f => (Int -> f Int) -> Foo a -> f (Foo a)






pt :: PlainRec (TElField Int) [DField 1, "name" :~>: String]
pt =   x    =: 10
   <+> name =: "frank"


pt2 :: PlainRec (TElField Int) (R 2 ++ '["name" :~>: String])
pt2 = cast $ pt <+> y =: 5

myPt2 :: Point 2 Int '["name" :~>: String]
myPt2 = point pt2


myPt :: Point 1 Int '["name" :~>: String]
myPt = point pt


-- myX :: Int
-- myX = case myPt of
--         Point pt' -> runIdentity $ rGet' x pt'




myX1 :: Int
myX1 = runIdentity $ rGet' x pt



-- type instance Dimension (Point d r p) = d
-- type instance NumType (Point d r p) = r

-- -- instance Num r => AffineSpace (Point d r p) where
-- --   type Diff (Point d r p) = Vec d r

-- --   p .-. q = asVec p ^-^  asVec q

-- --   (Point u fs) .+^ v = Point (u ^+^ v) fs


-- asVec             :: Point d r p -> Vec d r
-- asVec (Point v _) = v


--------------------------------------------------------------------------------
-- | Constructing Points

-- fromVector :: Vec d r -> Point d r '[]
-- fromVector = flip Point RNil

-- origin :: Num r => Point d r '[]
-- origin = fromVector zeroV
