module Analysis.CriticalPairs
  ( CriticalPairType (..)
  , CriticalPair (..)
  , getCriticalPairMatches
  , getCriticalPairComatches
  , getNacIndexOfCriticalPair
  , getNacMatchOfCriticalPair
  , getCriticalPairType

   -- * Finding Critical Pairs
  , findCriticalPairs
  , namedCriticalPairs
  , findAllDeleteUse
  , findAllProduceForbid
  , findAllProduceDangling
  , findAllDeleteUseAndProduceDangling
  ) where

import           Data.Maybe                               (mapMaybe)

import           Abstract.Category.Finitary
import           Abstract.Rewriting.DPO                   hiding (calculateComatch)
import           Abstract.Rewriting.DPO.DiagramAlgorithms
import           Util.List                                (parallelMap)

-- | Data representing the type of a 'CriticalPair'
data CriticalPairType =
    FreeOverlap
  | DeleteUse
  | ProduceForbid
  | ProduceDangling
  deriving(Eq,Show)

type NamedRule morph = (String, Production morph)
type NamedCriticalPairs morph = (String,String,[CriticalPair morph])

-- | A Critical Pair is defined as two matches (m1,m2) from the left
-- side of their productions to a same graph.
-- It assumes that the derivation of the production with match @m1@ causes
-- a conflict with the production with match @m2@
--
-- This diagram shows graphs and morphisms names used in the algorithms below
--
-- p1 = production (L1,K1,R1,[N1])
--
-- p2 = production (L2,K2,R2,[N2])
--
-- @
--                    N1    N2
--                    ^      ^
--          r     l   │      │n
--     R1◀─────K1────▶L1    L2◀────K2─────▶R2
--     │       │       \\   /       │       │
--  m1'│      k│      m1\\ /m2      │       │
--     ▼       ▼         ▼         ▼       ▼
--     P1◀─────D1───────▶G◀───────D2──────▶P2
--         r'       l'
-- @
--
-- m2' :: from L2 to P1
--
-- h21 :: from L2 to D1
--
-- q21 (nacMatch) :: from N2 to P1

data CriticalPair morph = CriticalPair {
    matches   :: (morph,morph),
    comatches :: Maybe (morph,morph),
    nacMatch  :: Maybe (morph, Int), --if it is a ProduceForbid, here is the index of the nac
    cpType    :: CriticalPairType
    } deriving (Eq,Show)

-- | Returns the matches (m1,m2)
getCriticalPairMatches :: CriticalPair morph -> (morph,morph)
getCriticalPairMatches = matches

-- | Returns the comatches (m1',m2')
getCriticalPairComatches :: CriticalPair morph -> Maybe (morph,morph)
getCriticalPairComatches = comatches

-- | Returns the type of a Critical Pair
getCriticalPairType :: CriticalPair morph -> CriticalPairType
getCriticalPairType = cpType

-- | Returns the nac match of a 'CriticalPair'
getNacMatchOfCriticalPair :: CriticalPair morph -> Maybe morph
getNacMatchOfCriticalPair criticalPair =
  case nacMatch criticalPair of
    Just (nac,_) -> Just nac
    Nothing      -> Nothing

-- | Returns the nac index of a 'CriticalPair'
getNacIndexOfCriticalPair :: CriticalPair morph -> Maybe Int
getNacIndexOfCriticalPair criticalPair =
  case nacMatch criticalPair of
    Just (_,idx) -> Just idx
    Nothing      -> Nothing

-- | Returns the Critical Pairs with rule names
namedCriticalPairs :: (E'PairCofinitary morph, DPO morph) => MorphismsConfig morph -> [NamedRule morph] -> [NamedCriticalPairs morph]
namedCriticalPairs conf namedRules =
  parallelMap (uncurry getCPs) [(a,b) | a <- namedRules, b <- namedRules]
    where
      getCPs (n1,r1) (n2,r2) =
        (n1, n2, findCriticalPairs conf r1 r2)

-- | Finds all Critical Pairs between two given Productions
findCriticalPairs :: (E'PairCofinitary morph, DPO morph) => MorphismsConfig morph -> Production morph -> Production morph -> [CriticalPair morph]
findCriticalPairs conf p1 p2 =
  findAllDeleteUseAndProduceDangling conf p1 p2 ++ findAllProduceForbid conf p1 p2

-- ** Conflicts

-- *** Delete-Use

-- | All DeleteUse caused by the derivation of @p1@ before @p2@.
-- It occurs when @p1@ deletes something used by @p2@.
findAllDeleteUse :: (E'PairCofinitary morph, DPO morph) => MorphismsConfig morph -> Production morph -> Production morph -> [CriticalPair morph]
findAllDeleteUse conf p1 p2 =
  let matchPairs = findJointSurjectiveApplicableMatches conf p1 p2
  in [ CriticalPair mpair Nothing Nothing DeleteUse | mpair <- matchPairs, isDeleteUse conf p1 mpair ]

-- *** Produce-Dangling

-- | All ProduceDangling caused by the derivation of @p1@ before @p2@.
-- It occurs when @p1@ creates something that unable @p2@.
findAllProduceDangling :: (E'PairCofinitary morph, DPO morph) => MorphismsConfig morph -> Production morph -> Production morph -> [CriticalPair morph]
findAllProduceDangling conf p1 p2 =
  let matchPairs = findJointSurjectiveApplicableMatches conf p1 p2
  in [ CriticalPair mpair Nothing Nothing ProduceDangling | mpair <- matchPairs, isProduceDangling conf p1 p2 mpair ]

-- DeleteUse and Produce-Dangling

-- | Tests DeleteUse and ProduceDangling for the same pairs,
-- more efficient than deal separately.
findAllDeleteUseAndProduceDangling :: (E'PairCofinitary morph, DPO morph) => MorphismsConfig morph -> Production morph -> Production morph -> [CriticalPair morph]
findAllDeleteUseAndProduceDangling conf p1 p2 =
  let
    matchPairs = findJointSurjectiveApplicableMatches conf p1 p2
    conflicts = mapMaybe (deleteUseDangling conf p1 p2) matchPairs
  in map categorizeConflict conflicts
  where
    categorizeConflict x = case x of
      (Left m)  -> CriticalPair m Nothing Nothing DeleteUse
      (Right m) -> CriticalPair m Nothing Nothing ProduceDangling

-- *** Produce-Forbid

-- | All ProduceForbid caused by the derivation of @p1@ before @p2@.
--
-- Rule @p1@ causes a produce-forbid conflict with @p2@ if some
-- NAC in @p2@ fails to be satisfied after the aplication of @p1@.
findAllProduceForbid :: (E'PairCofinitary morph, DPO morph) => MorphismsConfig morph -> Production morph -> Production morph -> [CriticalPair morph]
findAllProduceForbid conf p1 p2 =
  let conflicts = concatMap (produceForbidOneNac conf p1 p2) (zip (nacs p2) [0..])
  in [ CriticalPair matches (Just comatches) (Just nac) ProduceForbid
        | (matches, comatches, nac) <- conflicts ]
