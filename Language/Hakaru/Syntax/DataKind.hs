{-# LANGUAGE DataKinds
           , PolyKinds
           , StandaloneDeriving
           , DeriveDataTypeable
           , ScopedTypeVariables
           #-}

{-# OPTIONS_GHC -Wall -fwarn-tabs #-}
----------------------------------------------------------------
--                                                    2015.06.28
-- |
-- Module      :  Language.Hakaru.Syntax.DataKind
-- Copyright   :  Copyright (c) 2015 the Hakaru team
-- License     :  BSD3
-- Maintainer  :  wren@community.haskell.org
-- Stability   :  experimental
-- Portability :  GHC-only
--
-- A data-kind for the universe of Hakaru types.
----------------------------------------------------------------
module Language.Hakaru.Syntax.DataKind
    (
    -- * The core definition of Hakaru types
      Hakaru(..)
    , HakaruFun(..)
    , HakaruCon(..) 
    -- *
    , Symbol
    , Code
    , HakaruType
    -- * Some \"built-in\" types
    -- Naturally, these aren't actually built-in, otherwise they'd
    -- be part of the 'Hakaru' data-kind.
    , HUnit, HPair, HEither, HList, HMaybe
    ) where

import Data.Typeable (Typeable)
{- -- BUG: this code does not work on my system(s). It generates some strange CPP errors.
import GHC.TypeLits (Symbol)
import Unsafe.Coerce
-}
type Symbol = String 

----------------------------------------------------------------
-- | The universe\/kind of Hakaru types.
data Hakaru
    = HNat
    | HInt
    | HProb -- ^ Non-negative real numbers (not the [0,1] interval!)
    | HReal -- ^ The real projective line (includes +/- infinity)
    | HMeasure !Hakaru
    | HArray   !Hakaru
    | HFun     !Hakaru !Hakaru

    -- The lists-of-lists are sum-of-products functors. The application
    -- form allows us to unroll fixpoints.
    | [[HakaruFun]] :$ !Hakaru
    | HTag !(HakaruCon Hakaru) [[HakaruFun]]
    deriving (Read, Show)


-- N.B., The @Proxy@ type from "Data.Proxy" is polykinded, so it
-- works for @Hakaru@ too. However, it is _not_ Typeable!
--
-- TODO: all the Typeable instances in this file are only used in
-- 'Language.Hakaru.Simplify.closeLoop'; it would be cleaner to
-- remove these instances and reimplement that function to work
-- without them.

deriving instance Typeable 'HNat
deriving instance Typeable 'HInt
deriving instance Typeable 'HProb
deriving instance Typeable 'HReal
deriving instance Typeable 'HMeasure
deriving instance Typeable 'HArray
deriving instance Typeable 'HFun
deriving instance Typeable '(:$)
deriving instance Typeable 'HTag


----------------------------------------------------------------
-- | The identity and constant functors on 'Hakaru'. This gives
-- us limited access to type-variables in @Hakaru@, for use in
-- recursive sums-of-products. Notably, however, it only allows a
-- single variable (namely the one bound by the closest binder) so
-- it can't encode mutual recursion or other non-local uses of
-- multiple binders.
--
-- Products and sums are represented as lists in the 'Hakaru'
-- data-kind itself, so they aren't in this datatype.
data HakaruFun = Id | K !Hakaru
    deriving (Read, Show)

deriving instance Typeable 'Id
deriving instance Typeable 'K


----------------------------------------------------------------
{- -- BUG: this code does not work on my system(s). It generates some strange CPP errors.
-- HACK: there is no way to produce a value level term of type
-- Symbol other than through the fromSing function in TypeEq, so
-- this should be safe.
instance Show Symbol where
    show x = show (unsafeCoerce x :: String)
-}


-- | The kind of user-defined Hakaru type constructors, which serves
-- as a tag for the sum-of-products representation of the user-defined
-- Hakaru type. The head of the 'HakaruCon' is a symbolic name, and
-- the rest are arguments to that type constructor. The @a@ parameter
-- is parametric, which is especially useful when you need a singleton
-- of the constructor. The argument positions are necessary to do
-- variable binding in Code. 'Symbol' is the kind of \"type level
-- strings\".
data HakaruCon a = HCon !Symbol | HakaruCon a :@ a
    deriving (Read, Show)
infixl 0 :@

deriving instance Typeable 'HCon
deriving instance Typeable '(:@)

{- -- BUG: Hakaru is not promotable here
-- | The Code type family allows users to extend the Hakaru language
-- by adding new types. The right hand side is the sum-of-products
-- representation of that type. See the \"built-in\" types for examples.
type family   Code (a :: HakaruCon Hakaru)   :: [[HakaruFun]]
type instance Code (HCon "Bool")             = '[ '[], '[] ]
type instance Code (HCon "Unit")             = '[ '[] ]
type instance Code (HCon "Maybe"  :@ a)      = '[ '[] , '[K a] ]
type instance Code (HCon "List"   :@ a)      = '[ '[] , '[K a, Id] ]
type instance Code (HCon "Pair"   :@ a :@ b) = '[ '[K a, K b] ]
type instance Code (HCon "Either" :@ a :@ b) = '[ '[K a], '[K b] ]


-- | A helper type alias for simplifying type signatures for
-- user-provided Hakaru types.
--
-- BUG: you cannot use this alias when defining other type aliases!
-- For some reason the type checker doesn't reduce the type family
-- applications, which prevents the use of these type synonyms in
-- class instance heads. Any type synonym created with 'HakaruType'
-- will suffer the same issue, so type synonyms must be written out
-- by hand— or copied from the GHC pretty printer, which will happily
-- reduce things in the repl, even in the presence of quantified
-- type variables.
type HakaruType t = HTag t (Code t)
{-
   >:kind! forall a b . HakaruType (HCon "Pair" :@ a :@ b)
   forall a b . HakaruType (HCon "Pair" :@ a :@ b) :: Hakaru
   = forall (a :: Hakaru) (b :: Hakaru).
     'HTag (('HCon "Pair" ':@ a) ':@ b) '['['K a, 'K b]]

type HBool       = HakaruType (HCon "Bool")
type HUnit       = HakaruType (HCon "Unit")
type HPair   a b = HakaruType (HCon "Pair"   :@ a :@ b)
type HEither a b = HakaruType (HCon "Either" :@ a :@ b)
type HList   a   = HakaruType (HCon "List"   :@ a)
type HMaybe  a   = HakaruType (HCon "Maybe"  :@ a)
-}

type HBool       = 'HTag ('HCon "Bool") '[ '[], '[] ]
type HUnit       = 'HTag ('HCon "Unit") '[ '[] ]
type HPair   a b = 'HTag (('HCon "Pair"   ':@ a) ':@ b) '[ '[ 'K a, 'K b] ]
type HEither a b = 'HTag (('HCon "Either" ':@ a) ':@ b) '[ '[ 'K a], '[ 'K b] ]
type HList   a   = 'HTag ('HCon "List"    ':@ a) '[ '[], '[ 'K a, 'Id] ]
type HMaybe  a   = 'HTag ('HCon "Maybe"   ':@ a) '[ '[], '[ 'K a] ]
-}
----------------------------------------------------------------
----------------------------------------------------------- fin.