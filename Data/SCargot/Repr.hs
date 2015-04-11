{-# LANGUAGE DeriveFunctor #-}

module Data.SCargot.Repr
       ( -- * Elementary SExpr representation
         SExpr(..)
         -- * Rich SExpr representation
       , RichSExpr(..)
       , toRich
       , fromRich
         -- * Well-Formed SExpr representation
       , WellFormedSExpr(..)
       , toWellFormed
       , fromWellFormed
       ) where

import Data.String (IsString(..))

-- | All S-Expressions can be understood as a sequence
--   of @cons@ cells (represented here by 'SCons'), the
--   empty list @nil@ (represented by 'SNil') or an
--   @atom@.
data SExpr atom
  = SCons (SExpr atom) (SExpr atom)
  | SAtom atom
  | SNil
    deriving (Eq, Show, Read, Functor)

instance IsString atom => IsString (SExpr atom) where
  fromString = SAtom . fromString

-- | Sometimes, the cons-based interface is too low
--   level, and we'd rather have the lists themselves
--   exposed. In this case, we have 'RSList' to
--   represent a well-formed cons list, and 'RSDotted'
--   to represent an improper list of the form
--   @(a b c . d)@. This representation is based on
--   the shape of the parsed S-Expression, and not on
--   how it was represented, so @(a . (b))@ is going to
--   be represented as @RSList[RSAtom a, RSAtom b]@
--   despite having been originally represented as a
--   dotted list.
data RichSExpr atom
  = RSList [RichSExpr atom]
  | RSDotted [RichSExpr atom] atom
  | RSAtom atom
    deriving (Eq, Show, Read, Functor)

instance IsString atom => IsString (RichSExpr atom) where
  fromString = RSAtom . fromString

-- |  It should always be true that
--
--   > fromRich (toRich x) == x
--
--   and that
--
--   > toRich (fromRich x) == x
toRich :: SExpr atom -> RichSExpr atom
toRich (SAtom a) = RSAtom a
toRich (SCons x xs) = go xs (toRich x:)
  where go (SAtom a) rs    = RSDotted (rs []) a
        go SNil rs         = RSList (rs [])
        go (SCons x xs) rs = go xs (rs . (toRich x:))

-- | This follows the same laws as 'toRich'.
fromRich :: RichSExpr atom -> SExpr atom
fromRich (RSAtom a) = SAtom a
fromRich (RSList xs) = foldr SCons SNil (map fromRich xs)
fromRich (RSDotted xs x) = foldr SCons (SAtom x) (map fromRich xs)

-- | A well-formed s-expression is one which does not
--   contain any dotted lists. This means that not
--   every value of @SExpr a@ can be converted to a
--   @WellFormedSExpr a@, although the opposite is
--   fine.
data WellFormedSExpr atom
  = WFSList [WellFormedSExpr atom]
  | WFSAtom atom
    deriving (Eq, Show, Read, Functor)

instance IsString atom => IsString (WellFormedSExpr atom) where
  fromString = WFSAtom . fromString

-- | This will be @Nothing@ if the argument contains an
--   improper list. It should hold that
--
--   > toWellFormed (fromWellFormed x) == Right x
--
--   and also (more tediously) that
--
--   > case toWellFormed x of
--   >   Left _  -> True
--   >   Right y -> x == fromWellFormed y
toWellFormed :: SExpr atom -> Either String (WellFormedSExpr atom)
toWellFormed SNil      = return (WFSList [])
toWellFormed (SAtom a) = return (WFSAtom a)
toWellFormed (SCons x xs) = do
  x' <- toWellFormed x
  go xs (x':)
  where go (SAtom a) rs = Left "Found atom in cdr position"
        go SNil rs      = return (WFSList (rs []))
        go (SCons x xs) rs = do
          x' <- toWellFormed x
          go xs (rs . (x':))

-- | Convert a WellFormedSExpr back into a SExpr.
fromWellFormed :: WellFormedSExpr atom -> SExpr atom
fromWellFormed (WFSAtom a)  = SAtom a
fromWellFormed (WFSList xs) =
  foldr SCons SNil (map fromWellFormed xs)
