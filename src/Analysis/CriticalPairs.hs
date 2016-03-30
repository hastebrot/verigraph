module Analysis.CriticalPairs
 (
   CP,
   CriticalPair,
   criticalPairs,
   namedCriticalPairs,
   allDeleteUse,
   allProduceForbid,
   allProdEdgeDelNode,
   getM1,
   getM2,
   getCPNac,
   getCP
   ) where

import           Abstract.Morphism
import           Analysis.GluingConditions
import           Analysis.EpiPairs (createPairs)
import qualified Analysis.Matches as MT
import qualified Graph.GraphMorphism as GM
import           Graph.GraphRule
import           Graph.TypedGraphMorphism
import qualified Graph.Rewriting as RW
import           Data.List (elemIndex)
import           Data.List.Utils (countElem)

-- | Data representing the type of a 'CriticalPair'
data CP = FOL | DeleteUse | ProduceForbid | ProduceEdgeDeleteNode deriving(Eq,Show)

-- | A Critical Pair is defined as two matches (m1,m2) from the left side of their rules to a same graph.
-- It assumes that the derivation of the rule with match @m1@ causes a conflict with the rule with match @m2@
data CriticalPair a b = CriticalPair {
    m1 :: TypedGraphMorphism a b,
    m2 :: TypedGraphMorphism a b,
    nac :: Maybe Int, --if is ProduceForbid, here is the index of the nac
    cp :: CP
    } deriving (Eq,Show)

-- | Returns the left morphism of a 'CriticalPair'
getM1 :: CriticalPair a b -> TypedGraphMorphism a b
getM1 = m1

-- | Returns the right morphism of a 'CriticalPair'
getM2 :: CriticalPair a b -> TypedGraphMorphism a b
getM2 = m2

-- | Returns the type of a 'CriticalPair'
getCP :: CriticalPair a b -> CP
getCP = cp

-- | Returns the nac number of a 'CriticalPair'
getCPNac :: CriticalPair a b -> Maybe Int
getCPNac = nac

--instance Show (CriticalPair a b) where
--  show (CriticalPair m1 m2 cp) = "{"++(show $ TGM.mapping m1)++(show $ TGM.mapping m2)++(show cp)++"}"

namedCriticalPairs :: Bool -> Bool -> [(String, GraphRule a b)] -> [(String,String,[CriticalPair a b])]
namedCriticalPairs nacInj inj r = map (\(x,y) -> getCPs x y) [(a,b) | a <- r, b <- r]
  where
    getCPs (n1,r1) (n2,r2) = (n1, n2, criticalPairs nacInj inj r1 r2)

-- | All Critical Pairs
criticalPairs :: Bool -> Bool
              -> GraphRule a b
              -> GraphRule a b
              -> [CriticalPair a b]
--criticalPairs nacInj inj l r = (allDeleteUse nacInj inj l r) ++ (allProduceForbid nacInj inj l r) ++ (allProdEdgeDelNode nacInj inj l r)
criticalPairs nacInj inj l r = (allDeleteUseAndProdEdgeDelNode nacInj inj l r) ++ (allProduceForbid nacInj inj l r)

---- Delete-Use

-- | Tests DeleteUse and ProdEdgeDelNode for the same pairs
-- more efficient than deal separately
allDeleteUseAndProdEdgeDelNode :: Bool -> Bool
                               -> GraphRule a b
                               -> GraphRule a b
                               -> [CriticalPair a b]
allDeleteUseAndProdEdgeDelNode nacInj i l r = deleteUseCPs ++ prodEdgeCPs
  where
    pairs = createPairs (left l) (left r)                                --get all jointly surjective pairs of L1 and L2
    inj = filter (\(m1,m2) -> monomorphism m1 && monomorphism m2) pairs --check injective
    gluing = filter (\(m1,m2) -> satsGluingCondBoth nacInj (l,m1) (r,m2)) (if i then inj else pairs) --filter the pairs that not satisfie gluing conditions of L and R
    deleteUseList = filter (deleteUse l r) gluing                               --select just the pairs that are in DeleteUse conflict
    deleteUseCPs = map (\(m1,m2) -> CriticalPair m1 m2 Nothing DeleteUse) deleteUseList
    prodEdgeList = filter (prodEdgeDelNode l r) gluing
    prodEdgeCPs = map (\(m1,m2) -> CriticalPair m1 m2 Nothing ProduceEdgeDeleteNode) prodEdgeList

-- | All DeleteUse caused by the derivation of @l@ before @r@
allDeleteUse :: Bool -> Bool
             -> GraphRule a b
             -> GraphRule a b
             -> [CriticalPair a b]
allDeleteUse nacInj i l r = map (\(m1,m2) -> CriticalPair m1 m2 Nothing DeleteUse) delUse
    where
        pairs = createPairs (left l) (left r)                                --get all jointly surjective pairs of L1 and L2
        inj = filter (\(m1,m2) -> monomorphism m1 && monomorphism m2) pairs --check injective
        gluing = filter (\(m1,m2) -> satsGluingCondBoth nacInj (l,m1) (r,m2)) (if i then inj else pairs) --filter the pairs that not satisfie gluing conditions of L and R
        delUse = filter (deleteUse l r) gluing                               --select just the pairs that are in DeleteUse conflict

-- | DeleteUse using a most aproximated algorithm of the categorial diagram
-- Verify the non existence of h21: L2 -> D1 such that d1 . h21 = m2
deleteUse2 :: GraphRule a b -> GraphRule a b
           -> (TypedGraphMorphism a b,TypedGraphMorphism a b)
           -> Bool
deleteUse2 l r (m1,m2) = null filt
    where
        (_,d1) = RW.poc m1 (left l) --get only the morphism D2 to G
        l2TOd1 = MT.matches (domain m2) (domain d1) MT.FREE
        filt = filter (\x -> m2 == compose x d1) l2TOd1

-- | Rule @l@ causes a delete-use conflict with @r@ if rule @l@ deletes something that is used by @r@
-- @(m1,m2)@ is a pair of matches on the same graph
deleteUse :: GraphRule a b -> GraphRule a b
          -> (TypedGraphMorphism a b,TypedGraphMorphism a b)
          -> Bool
deleteUse l r (m1,m2) = any (==True) (nods ++ edgs)
    where
        nods = deleteUseAux l m1 m2 GM.applyNode nodesDomain nodesCodomain
        edgs = deleteUseAux l m1 m2 GM.applyEdge edgesDomain edgesCodomain

-- | Verify if some element in a graph is deleted by @l@ and is in the match of @r@
deleteUseAux :: Eq t => GraphRule a b -> TypedGraphMorphism a b -> TypedGraphMorphism a b
                     -> (GM.GraphMorphism a b -> t -> Maybe t)
                     -> (TypedGraphMorphism a b -> [t]) --domain
                     -> (TypedGraphMorphism a b -> [t]) --codomain
                     -> [Bool]
deleteUseAux l m1 m2 apply dom cod = map (\x -> delByLeft x && isInMatchRight x) (cod m1)
    where
        delByLeft = ruleDeletes l m1 apply dom
        isInMatchRight n = apply (GM.inverse $ mapping m2) n /= Nothing

---- Produce Edge Delete Node

allProdEdgeDelNode :: Bool -> Bool
                   -> GraphRule a b
                   -> GraphRule a b
                   -> [CriticalPair a b]
allProdEdgeDelNode nacInj i l r = map (\(m1,m2) -> CriticalPair m1 m2 Nothing ProduceEdgeDeleteNode) conflictPairs
    where
        pairs = createPairs (left l) (left r)
        inj = filter (\(m1,m2) -> monomorphism m1 && monomorphism m2) pairs --check injective
        gluing = filter (\(m1,m2) -> satsGluingCondBoth nacInj (l,m1) (r,m2)) (if i then inj else pairs) --filter the pairs that not satisfie gluing conditions of L and R
        conflictPairs = filter (prodEdgeDelNode l r) gluing

prodEdgeDelNode :: GraphRule a b -> GraphRule a b -> (TypedGraphMorphism a b,TypedGraphMorphism a b) -> Bool
prodEdgeDelNode l r (m1,m2) = not (satsIncEdges r lp)
    where
        (_,p,l',r') = RW.dpo m1 l
        gd = invertTGM l'
        ld = compose m2 gd
        lp = compose ld r'

---- Produce-Forbid

-- | All ProduceForbid caused by the derivation of @l@ before @r@
-- rule @l@ causes a produce-forbid conflict with @r@ if some NAC in @r@ fails to be satisfied after the aplication of @l@
allProduceForbid :: Bool -> Bool
                 -> GraphRule a b
                 -> GraphRule a b
                 -> [CriticalPair a b]
allProduceForbid nacInj inj l r = concat (map (produceForbidOneNac nacInj inj l r) (nacs r))

-- | Check ProduceForbid for a NAC @n@ in @r@
produceForbidOneNac :: Bool -> Bool
                    -> GraphRule a b -> GraphRule a b
                    -> TypedGraphMorphism a b
                    -> [CriticalPair a b]
produceForbidOneNac nacInj inj l r n = let
        inverseLeft = inverseWithoutNacs l

        -- Consider for a NAC n (L2 -> N2) of r any jointly surjective
        -- pair of morphisms (h1: R1 -> P1, q21: N2 -> P1) with q21 (part)inj
        pairs = createPairs (right l) n
        
        filtFun = if nacInj then monomorphism else partialInjectiveTGM n
        filtMono = filter (\(_,q) -> filtFun q) pairs --(h1,q21)

        -- Check gluing cond for (h1,r1). Construct PO complement D1.
        filtPairs = filter (\(h1,_) -> satsGluingCond nacInj inverseLeft h1) filtMono

        poc = map (\(h1,q21) -> let (k,r') = RW.poc h1 (left inverseLeft) in
                                 (h1,q21,k,r'))
                 filtPairs --(h1,q21,k,r')

        -- Construct PO K and abort if m1 not sats NACs l
        po = map (\(h1,q21,k,r') ->
                   let (m1,l') = RW.po k (right inverseLeft) in
                     (h1,q21,k,r',m1,l'))
                 poc --(h1,q21,k,r',m1,l')

        filtM1 = filter (\(_,_,_,_,m1,_) -> satsNacs nacInj l m1) po

        --  Check existence of h21: L2 -> D1 st. e1 . h21 = q21 . n2
        h21 = concat $
                map (\(h1,q21,k,r',m1,l') ->
                  let hs = MT.matches (domain n) (codomain k) MT.FREE in
                    case null hs of
                      True  -> []
                      False -> [(h1,q21,k,r',m1,l',hs)])
                  filtM1 --(h1,q21,k,r',m1,l1,[hs])

        validH21 = concat $
                     map (\(h1,q21,k,r',m1,l',hs) ->
                       let list = map (\h -> compose h r' == compose n q21) hs in
                         case (elemIndex True list) of
                           Just ind -> [(h1,q21,k,r',m1,l',hs!!ind)]
                           Nothing  -> [])
                       h21

        -- Define m2 = d1 . h21: L2 -> K and abort if m2 not sats NACs r
        m1m2 = map (\(h1,q21,k,r',m1,l',l2d1) -> (h1,m1, compose l2d1 l')) validH21
        --filtM2 = filter (\(m1,m2) -> satsNacs r m2) m1m2

        -- Check gluing condition for m2 and r
        filtM2 = filter (\(_,m1,m2) -> satsGluingCond nacInj r m2) m1m2
        
        filtInj = filter (\(_,m1,m2) -> monomorphism m1 && monomorphism m2) filtM2
        
        idx = elemIndex n (nacs r)
        
        in map (\(h1,m1,m2) -> CriticalPair h1 m2 idx ProduceForbid) (if inj then filtInj else filtM2)
