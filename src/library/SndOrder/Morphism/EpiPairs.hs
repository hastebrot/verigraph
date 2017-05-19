{-# LANGUAGE TypeFamilies #-}

module SndOrder.Morphism.EpiPairs where

import           Category.AdhesiveHLR
import           Category.DPO
import           Category.FinitaryCategory
import           TypedGraph.Morphism

import           SndOrder.Morphism.Core

instance EpiPairs (RuleMorphism a b) where
  createJointlyEpimorphicPairs inj m1 m2 = ret
    where
      createJointly x y = createJointlyEpimorphicPairs inj (codomain x) (codomain y)
      
      leftM1 = getLHS m1
      rightM1 = getRHS m1
      leftM2 = getLHS m2
      rightM2 = getRHS m2
      k1 = domain leftM1
      k2 = domain leftM2

      ks = createJointlyEpimorphicPairs inj k1 k2

      lefts = concatMap
                (\(k1,k2) -> let ls = createSideRule createJointly k1 leftM1 leftM1 k2 leftM2 leftM2
                             in map (\(ll1,ll2,m) -> (k1, k2, ll1, ll2, m)) ls) ks
      rights = concatMap
                (\(k1,k2,ll1,ll2,l) -> let rs = createSideRule createJointly k1 rightM1 rightM1 k2 rightM2 rightM2
                                       in map (\(rr1,rr2,r) -> (k1,k2,ll1,ll2,l,rr1,rr2,r)) rs) lefts

      transposeNACs l = map (snd . calculatePushout l)

      ret = map (\(k1,k2,ll1,ll2,l,r1,r2,r) ->
                   let rule = buildProduction l r $ transposeNACs ll1 (getNACs m1) ++ transposeNACs ll2 (getNACs m2)
                   in (ruleMorphism m1 rule ll1 k1 r1,
                       ruleMorphism m2 rule ll2 k2 r2)) rights

  createAllSubobjects _ _ = error "CreateAllSubobjects for RuleMorphism: Not implemented"

  createJointlyEpimorphicPairsFromNAC conf ruleR nac = ret
    where
      createJointly x = createJointlyEpimorphicPairsFromNAC conf (codomain x)
      
      nL = mappingLeft nac
      nK = mappingInterface nac
      nR = mappingRight nac
      leftR = getLHS ruleR
      rightR = getRHS ruleR
      rK = domain (getLHS ruleR)
      codNac = codomain nac
      
      interfaceEpiPairs = createJointlyEpimorphicPairsFromNAC conf rK nK
      
      lefts = concatMap
                (\(kR,kN) ->
                  let ls = createSideRule createJointly kR leftR leftR kN (getLHS codNac) nL
                  in map (\(ll1,ll2,m) -> (kR, kN, ll1, ll2, m)) ls)
                interfaceEpiPairs
      
      rights = concatMap
                (\(kR,kN,ll1,ll2,l) ->
                  let rs = createSideRule createJointly kR rightR rightR kN (getRHS codNac) nR
                  in map (\(rr1,rr2,r) -> (kR,kN,ll1,ll2,l,rr1,rr2,r)) rs)
                lefts
      
      transposeNACs l = map (snd . calculatePushout l)

      ret = map (\(k1,k2,ll1,ll2,l,r1,r2,r) ->
                   let rule = buildProduction l r $ transposeNACs ll1 (getNACs ruleR) ++ transposeNACs ll2 (getNACs codNac)
                   in (ruleMorphism ruleR rule ll1 k1 r1,
                       ruleMorphism (codomain nac) rule ll2 k2 r2)) rights

  calculateCommutativeSquaresAlongMonomorphism (m1,inj1) (m2,inj2) = filt
    where
      allCommutingPairs = calculateCommutativeSquares False m1 m2
      satsM1 = if inj1 then isMonomorphism else const True
      satsM2 = if inj2 then isMonomorphism else const True
      filt = filter (\(m1,m2) -> satsM1 m1 && satsM2 m2) allCommutingPairs

-- | Generates all (ss1,ss2,m) morphisms that commute with all EpiPairs
-- of S1 and S2.
-- Morphism morph is always monomorphic.
-- createS must create all ss1 and ss2 from create1 and create2.
--
-- @
--        sideM1
--      K1─────▶S1
--      │       :
--    k1│       :ss1
--      ▼   m   ▼
--      K------▶S
--      ▲       ▲
--    k2│       :ss2
--      │       :
--      K2─────▶S2
--        sideM2
-- @
createSideRule :: (TypedGraphMorphism a b -> TypedGraphMorphism a b -> [(TypedGraphMorphism a b, TypedGraphMorphism a b)])
            -> TypedGraphMorphism a b -> TypedGraphMorphism a b -> TypedGraphMorphism a b
            -> TypedGraphMorphism a b -> TypedGraphMorphism a b -> TypedGraphMorphism a b
            -> [(TypedGraphMorphism a b, TypedGraphMorphism a b, TypedGraphMorphism a b)]
createSideRule createS k1 sideM1 create1 k2 sideM2 create2 = d
  where
    a = createS create1 create2
    b = concatMap (\(ss1,ss2) -> sequence [[ss1],[ss2], findMonomorphisms (codomain k1) (codomain ss1)]) a
    c = map (\(x:y:z:_) -> (x,y,z)) b
    d = filter (\(ss1,ss2,m) -> compose sideM1 ss1 == compose k1 m &&
                                compose sideM2 ss2 == compose k2 m) c
