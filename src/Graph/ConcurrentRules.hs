module Graph.ConcurrentRules
( allConcurrentRules,
  maxConcurrentRule
) where

import qualified Abstract.Morphism        as M
import qualified Analysis.CriticalPairs
import           Analysis.EpiPairs
import           Analysis.GluingConditions
import           Data.List
import           Data.Maybe               (isJust)
import           Graph.GraphRule
import           Graph.NacOperations
import qualified Graph.Rewriting          as R
import qualified Graph.TypedGraphMorphism as TGM

type EpiPair a b = (TGM.TypedGraphMorphism a b, TGM.TypedGraphMorphism a b)

-- | Generates the Concurrent Rules for a given list of GraphRules following the order of the elements in the list. If the first argument evaluates to True, it will calculate only rules generated by Injective EpiPairs
allConcurrentRules :: Bool -> [GraphRule a b] -> [GraphRule a b]
allConcurrentRules _ [] = []
allConcurrentRules _ [x] = [x]
allConcurrentRules injectiveOnly (x:xs) = concatMap (crs x) (allCRs xs)
  where
    crs = concurrentRules injectiveOnly
    allCRs = allConcurrentRules injectiveOnly

-- | Generates the Concurrent Rule with the least disjoint EpiPair for a given list of GraphRules (following the order of the elements in the list). If the first argument evaluates to True, it will generate only the least disjoint injective EpiPair
maxConcurrentRule :: Bool -> [GraphRule a b] -> GraphRule a b
maxConcurrentRule injectiveOnly rules = last $ maxConcurrentRules injectiveOnly rules

maxConcurrentRules :: Bool -> [GraphRule a b] -> [GraphRule a b]
maxConcurrentRules _ [] = []
maxConcurrentRules _ [x] = [x]
maxConcurrentRules injectiveOnly (x:xs) = map (singleCR x) (maxCRs xs)
  where
    singleCR = maxConcurrentRuleForLastPair injectiveOnly
    maxCRs = maxConcurrentRules injectiveOnly

concurrentRules :: Bool -> GraphRule a b -> GraphRule a b -> [GraphRule a b]
concurrentRules isInjective c n = map (concurrentRuleForPair c n) $ pairs isInjective c n

pairs :: Bool -> GraphRule a b -> GraphRule a b -> [EpiPair a b]
pairs isInjective c n = if isInjective then injectivePairs else validDpoPairs
  where
    allPairs  = createPairs (right c) (left n)
    validDpoPairs = filter (\(lp, rp) -> satsGluing True (right c) lp && satsGluing True (left n) rp) allPairs
    injectivePairs = filter (\(lp, rp) -> (M.monomorphism lp) && (M.monomorphism rp)) validDpoPairs

maxConcurrentRuleForLastPair :: Bool -> GraphRule a b -> GraphRule a b -> GraphRule a b
maxConcurrentRuleForLastPair isInjective c n = concurrentRuleForPair c n (last $ pairs isInjective c n)

concurrentRuleForPair :: GraphRule a b -> GraphRule a b -> EpiPair a b -> GraphRule a b
concurrentRuleForPair c n pair = graphRule l r (dmc ++ lp)
  where
    pocC = R.poc (fst pair) (right c)
    pocN = R.poc (snd pair) (left n)
    poC = R.po (fst pocC) (left c)
    poN = R.po (fst pocN) (right n)
    pb = injectivePullback (snd pocC) (snd pocN)
    l = M.compose (fst pb) (snd poC)
    r = M.compose (snd pb) (snd poN)
    dmc = concatMap (downwardShift (fst poC)) (nacs c)
    p = graphRule (snd poC) (snd pocC) []
    den = concatMap (downwardShift (snd pair)) (nacs n)
    lp = concatMap (leftShiftNac False p) den

injectivePullback :: TGM.TypedGraphMorphism a b -> TGM.TypedGraphMorphism a b -> (TGM.TypedGraphMorphism a b, TGM.TypedGraphMorphism a b)
injectivePullback f g = (delNodesFromF', delNodesFromG')
  where
    f' = TGM.invertTGM f
    g' = TGM.invertTGM g
    nodes = TGM.nodesDomain f'
    edges = TGM.edgesDomain f'
    knodes = filter (\n -> isJust (TGM.applyNodeTGM f' n) && isJust (TGM.applyNodeTGM g' n)) nodes
    kedges = filter (\e -> isJust (TGM.applyEdgeTGM f' e) && isJust (TGM.applyEdgeTGM g' e)) edges
    delNodes = nodes \\ knodes
    delEdges = edges \\ kedges
    delEdgesFromF' = foldr TGM.removeEdgeDomTyped f' delEdges
    delNodesFromF' = foldr TGM.removeNodeDomTyped delEdgesFromF' delNodes
    delEdgesFromG' = foldr TGM.removeEdgeDomTyped g' delEdges
    delNodesFromG' = foldr TGM.removeNodeDomTyped delEdgesFromG' delNodes

