{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Data.Geometry.Vector( Vec(Vec)
                           , toList
                           ) where

import Control.Applicative

import Data.List(genericReplicate)

import Linear.Affine
import Linear.Vector


import Data.Vinyl


import GHC.TypeLits

--------------------------------------------------------------------------------

newtype Vec (d :: Nat) r = Vec { toList :: [r] }
                           deriving (Show,Eq,Ord)


-- pure'   :: forall a d. SingI (d :: Nat) => a -> Vec d a
-- pure' x = Vec $ genericReplicate (fromSing (sing :: Sing (d :: Nat))) x

vZipWith                     :: forall a b c d.
                                (a -> b -> c) -> Vec d a -> Vec d b -> Vec d c
vZipWith f (Vec xs) (Vec ys) = Vec $ zipWith f xs ys

app' :: forall a b d . Vec d (a -> b) -> Vec d a -> Vec d b
app' = vZipWith ($)




instance Functor (Vec d) where
  fmap f (Vec xs) = Vec $ fmap f xs

instance Applicative (Vec d) where
  pure  = undefined  -- pure'
  (<*>) = app'

instance Additive (Vec d) where
  zero = pure 0
  (^+^) = vZipWith (+)

instance Affine (Vec d) where
  type Diff (Vec d) = Vec d

  u .-. v = u ^-^ v
  p .+^ v = p ^+^ v


-- negateV = fmap negate

-- instance Num r => VectorSpace (Vec d r) where
--   type Scalar (Vec d r) = r
--   s *^ v = fmap (s*) v

-- instance (AdditiveGroup r, Num r) => InnerSpace (Vec d r) where
--   v <.> v' = let (Vec r) = vZipWith (*) v v' in
--              sum r



test :: Vec 3 Int
test = zero

foo :: Vec 3 Int
foo = Vec [1,2,3]


-- data Vec (d :: Nat) (a :: *) where
--   Nil  ::                 Vec 0       a
--   (:.) :: a -> Vec d a -> Vec (d + 1) a


-- -- myVec :: Vec 2 Int
-- myVec = 1 :. (2 :. Nil)


-- vReplicate     :: Sing (n :: Nat) -> a -> Vec n a
-- vReplicate s x = case fromSing s of
--                    0 -> Nil
--                    _ -> x :. vReplicate (sing') x
--   where
--     sing' = sing :: Sing ((n - 1) :: Nat)


-- vZipWith                       :: (a -> b -> c) -> Vec d a -> Vec d b -> Vec d c
-- vZipWith f Nil       _         = Nil
-- -- vZipWith f (x :. xs) (y :. ys) = f x y :. vZipWith f xs ys

-- vReplicate :: (Num r, SingE (n:: Nat)) => Vec n r
-- vReplicate = case fromSing (sing :: Nat) of
--                0 -> Nil
--                m ->