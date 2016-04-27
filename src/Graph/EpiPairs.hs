{-# OPTIONS_GHC -fno-warn-orphans #-}
module Graph.EpiPairs () where

import           Abstract.AdhesiveHLR
import           Graph.TypedGraphMorphism (TypedGraphMorphism)
import           Partitions.GPToVeri      (mountTGMBoth)
import           Partitions.GraphPart     (genGraphEqClass)
import           Partitions.VeriToGP      (mixGM,mixNac)

instance EpiPairs (TypedGraphMorphism a b) where
  -- | Create all jointly surjective pairs of @m1@ and @m2@
  createPairs inj m1 m2 = map (mountTGMBoth m1 m2) (genGraphEqClass (mixGM (m1,inj) (m2,inj)))

  -- | Create all jointly surjective pairs of @m1@ and @m2@ with some of both injective
  --createPairsAlt (m1,inj1) (m2,inj2) = map (mountTGMBoth m1 m2) (genGraphEqClass (mixGM (m1,inj1) (m2,inj2)))
  
  createPairsNac nacInj inj r nac = map (mountTGMBoth r (codomain nac)) (genGraphEqClass (mixNac (r,inj) (nac,nacInj)))

  -- | Create all jointly surjective pairs of @m1@ and @m2@ that commutes, considering they have same domain
  commutingPairs inj m1 m2 = filt
    where
      allPairs = createPairs inj (codomain m1) (codomain m2)
      filt = filter (\(x,y) -> compose m1 x == compose m2 y) allPairs
      
  -- | Create all jointly surjective pairs of @m1@ and @m2@ that commutes,
  -- considering they have same domain
  -- and flags indicating the injective of each morphism
  commutingPairsAlt (m1,inj1) (m2,inj2) = filt
    where
      cod1 = codomain m1
      cod2 = codomain m2
      allPairs = map (mountTGMBoth cod1 cod2) (genGraphEqClass (mixGM (cod1,inj1) (cod2,inj2)))
      filt = filter (\(x,y) -> compose m1 x == compose m2 y) allPairs