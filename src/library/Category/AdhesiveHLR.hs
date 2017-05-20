{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}

module Category.AdhesiveHLR
  ( FinitaryCategory(..)
  , AtomicConstraint (..)
  , buildNamedAtomicConstraint
  , satisfiesAtomicConstraint
  , satisfiesAllAtomicConstraints
  , Constraint (..)
  , satisfiesConstraint
  , satisfiesAllConstraints
  , EpiPairs(..)
  , AdhesiveHLR(..)

  , MatchRestriction(..)
  , matchRestrictionToMorphismType
  , NacSatisfaction(..)
  , MorphismsConfig(..)
  ) where

import           Category.AdhesiveHLR.Constraint
import           Category.Cocomplete
import           Category.FinitaryCategory

-- | Type class for morphisms whose category Adhesive and suitable for
-- High-Level Replacement Systems.
--
-- Mainly provides categorical operations that AdhesiveHLR categories
-- are guaranteed to have.
class (Cocomplete morph) => AdhesiveHLR morph where
  -- | Calculate the initial pushout of the given morphism.
  --
  -- Given the morphism /f : A -> A'/, returns
  -- the morphisms /b : B -> A/, /f' : B -> C/ and /c: C -> A'/ such that
  -- the following square is the initial pushout of f.
  --
  -- @
  --        f'
  --    B──────▶C
  --    │       │
  --  b │       │ c
  --    ▼       ▼
  --    A──────▶A'
  --        f
  -- @
  calculateInitialPushout :: morph -> (morph,morph,morph)

  -- | Calculate the pushout between the two given morphisms.
  --
  -- Given the morphisms /f : A -> B/ and /g : A -> C/, respectively, returns
  -- the pair of morphisms /f' : C -> D/ and /g': B -> D/ such that the
  -- following square is a pushout.
  --
  -- @
  --       g
  --    A──────▶C
  --    │       │
  --  f │       │ f'
  --    ▼       ▼
  --    B──────▶D
  --       g'
  -- @
  calculatePushout :: morph -> morph -> (morph,morph)
  calculatePushout = Category.Cocomplete.calculatePushout

  -- | Checks if the given sequential morphisms have a pushout complement, assuming they satsify
  -- the given restriction.
  --
  -- Given the morphisms /g : B -> C/ and /f : A -> B/, respectively, tests if
  -- there exists a pair of morphisms /f' : A -> X/ and /g' : X -> B/ such that the
  -- following square is a pushout. Since the category is Adhesive, such a pair is unique.
  --
  -- @
  --        f
  --     A──────▶B
  --     │       │
  --  g' │       │ g
  --     ▼       ▼
  --     X──────▶C
  --        f'
  -- @
  --
  -- If the types of the morphisms are known, they should be given. The implementation
  -- of this operation may then use them for more efficient calculation.
  hasPushoutComplement :: (MorphismType, morph) -> (MorphismType, morph) -> Bool


  -- | Calculate the pushout complement for two sequential morphisms, __assumes it exists__.
  --
  -- In order to test if the pushout complement exists, use 'hasPushoutComplement'.
  --
  -- Given the morphisms /g : B -> C/ and /f : A -> B/, respectively, returns
  -- the pair of morphisms /f' : A -> X/ and /g' : X -> B/ such that the
  -- following square is a pushout. Since the category is Adhesive, such a pair is unique.
  --
  -- @
  --        f
  --     A──────▶B
  --     │       │
  --  g' │       │ g
  --     ▼       ▼
  --     X──────▶C
  --        f'
  -- @
  calculatePushoutComplement :: morph -> morph -> (morph,morph)

  -- | Calculate the pullback between the two given morphisms.
  --
  -- Given two morphisms /f : A -> C/ and /g : B -> C/, respectively, returns
  -- the pair of morphisms /f' : X -> B/ and /g': X -> A/ such that the
  -- following square is a pullback.
  --
  -- @
  --        g'
  --     X──────▶A
  --     │       │
  --  f' │       │ f
  --     ▼       ▼
  --     B──────▶C
  --        g
  -- @
  calculatePullback :: morph -> morph -> (morph,morph)

class FinitaryCategory morph => EpiPairs morph where
  -- | Create all jointly epimorphic pairs of morphisms from the given objects.
  --
  -- If the first argument is true, only pairs of monomorphisms are created.
  -- Otherwise, pairs of arbitrary morphisms are created.
  createJointlyEpimorphicPairs :: Bool -> Obj morph -> Obj morph -> [(morph,morph)]

  -- | Create all subobjects from the given object.
  --
  -- If the first argument is true, only identity morphism is created.
  -- Otherwise, arbitrary (epimorphic) morphisms are created.
  createAllSubobjects :: Bool -> Obj morph -> [morph]

  -- | Create a special case of jointly epimorphic pairs, where the second morphism is a Nac.
  -- The pairs generated are dependent of the NAC config.
  --
  -- FIXME: nacs don't belong in this module
  createJointlyEpimorphicPairsFromNAC :: MorphismsConfig -> Obj morph -> morph -> [(morph,morph)]

  -- Given the morphisms /f : X -> A/ and /g : X -> B/ with the same domain,
  -- obtain all jointly epimorphic pairs /(f', g')/ such that the following
  -- diagram commutes.
  -- @
  --        g
  --     X──────▶B
  --     │       │
  --   f │       │ f'
  --     ▼       ▼
  --     A──────▶Y
  --        g'
  -- @
  --
  -- If the first argument is true, only pairs of monomorphisms are created.
  -- Otherwise, pairs of arbitrary morphisms are created.
  calculateCommutativeSquares :: Bool -> morph -> morph -> [(morph,morph)]
  calculateCommutativeSquares inj m1 m2 = filt
    where
      allPairs = createJointlyEpimorphicPairs inj (codomain m1) (codomain m2)
      filt = filter (\(x,y) -> x <&> m1 == y <&> m2) allPairs

  -- Similar to calculateCommutativeSquares but indicating which morphism is injective
  calculateCommutativeSquaresAlongMonomorphism :: (morph,Bool) -> (morph,Bool) -> [(morph,morph)]


-- | Flag indicating what restrictions are required or assumed of matches.
data MatchRestriction = MonoMatches | AnyMatches deriving (Eq, Show)

-- | Converts a match restriction to the corresponding MorphismType
matchRestrictionToMorphismType :: MatchRestriction -> MorphismType
matchRestrictionToMorphismType MonoMatches = Monomorphism
matchRestrictionToMorphismType AnyMatches  = GenericMorphism

-- | Flag indicating the semantics of NAC satisfaction.
data NacSatisfaction = MonomorphicNAC | PartiallyMonomorphicNAC deriving (Eq, Show)

data MorphismsConfig = MorphismsConfig
  { matchRestriction :: MatchRestriction
  , nacSatisfaction  :: NacSatisfaction
  }