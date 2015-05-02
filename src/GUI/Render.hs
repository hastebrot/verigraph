{-# LANGUAGE TemplateHaskell #-} -- fclabels

module GUI.Render (
      renderColor
    , render
    , drawNode
    , nodeRenderType
    , defRadius
    , edgeCenter
    , norm
    , directionVect
    ) where

import Control.Monad (guard)
import Data.Label -- fclabels
import Data.Maybe (fromJust)
--import GUI.Editing (State (..), GraphEditState (..))
import GUI.Editing
import Graphics.Rendering.Cairo as Gtk
import Graphics.UI.Gtk (Color (..))
import qualified Graph.Graph as G
import qualified Abstract.Relation as R
import Prelude hiding ((.))
import Control.Category


defRadius = 20 :: Double
defLineWidth = 2 :: Double
defBorderColor = Color 65535 65535 65535
defLineColor = Color 60000 0 0
ctrlPointColor = Color 65535 65535 0
defSpacing = 1

{- Data types for rendering -}
data RNode = RNode GramState GraphEditState G.NodeId
data REdge = REdge GramState GraphEditState G.EdgeId
data RGraph = RGraph Graph

class Renderable a where
    render :: a -> Render ()

instance Renderable RNode where
    render (RNode state gstate n) =
        case G.nodePayload g n of
            Just (coords, renderFunc, checkFunc) -> renderFunc state gstate n
            otherwise -> return ()
      where
        g = _getGraph gstate

instance Renderable REdge where
    render (REdge state gstate e) =
        let gr = get getGraph gstate
            coords = do
                (src, tgt) <- G.nodesConnectedTo gr e
                srcC <- fmap getCoords $ G.nodePayload gr src
                tgtC <- fmap getCoords $ G.nodePayload gr tgt
                p@(_, _, bendFactor, _) <- G.edgePayload gr e
                return (srcC, tgtC, bendFactor, p)
        in case coords of
            Just (srcC@(x, y), tgtC@(x', y'), bendFactor, p) -> do
                let (dirX, dirY) = directionVect srcC tgtC
                    dist = norm srcC tgtC
                    (scaledX, scaledY) = ( dirX * defRadius * bendFactor
                                         , dirY * defRadius * bendFactor )
                    bigRadius = defRadius * 4 -- for extra bend in loops
                    -- Control points coodinates.
                    (ctrlX, ctrlY, ctrlX', ctrlY')
                        -- dist == 0 tests for loops.
                        | dist == 0 = ( x - bendFactor - bigRadius
                                      , y - bendFactor - bigRadius
                                      , x + bendFactor + bigRadius
                                      , y - bendFactor - bigRadius )
                        | otherwise =
                          -- first bezier control point
                          -- the last terms from ctrlX and ctrlY form a right angle
                          -- to the direction vector.
                          ( x + dirX * (dist / 3) - scaledY
                          , y + dirY * (dist / 3) + scaledX
                          -- second bezier control point
                          , x + dirX * (2 * dist / 3) - scaledY
                          , y + dirY * (2 * dist / 3) + scaledX )
                    (dirX', dirY') = directionVect (ctrlX', ctrlY') (x', y')
                setLineWidth defLineWidth
                renderColor defLineColor

                moveTo x y
                curveTo ctrlX ctrlY ctrlX' ctrlY' x' y'
--                if sel p then strokePreserve >> highlight >> stroke else stroke
                stroke
                setLineWidth defLineWidth
                renderColor defLineColor
                moveTo x' y'
                relMoveTo (- defRadius * dirX') (- defRadius * dirY')
                rotate $ (angle (dirX', dirY'))
                drawHead $ defRadius * 1.5
--                if sel p then fillPreserve >> highlight >> fill else fill
                fill
                identityMatrix
                if sel p
                    then
                       do let (cx, cy) = edgeCenter srcC tgtC bendFactor
                          drawCtrlPoint cx cy
                          fill
                    else return ()
                identityMatrix
            Nothing -> return ()
        where
            getCoords (c, _, _) = c
            drawHead len = do
                relLineTo (-len / 2) (len / 4)
                relLineTo 0 (- len / 2)
                relLineTo (len / 2) (len / 4)
            drawCtrlPoint x y = do
                setLineWidth defLineWidth
                renderColor ctrlPointColor
                arc x y (defRadius / 4) 0 $ 2 * pi
            sel p = Edge e p `elem` get selObjects gstate
            highlight = setSourceRGBA 0 0 0 0.4


instance Renderable GramState where
    render state =
        case currentGraphState state of
            Just gstate -> do
                let gr = get getGraph gstate
                mapM_ (render . REdge state gstate) $ G.edges gr
                mapM_ (render . RNode state gstate) $ G.nodes gr
            Nothing -> return ()

renderColor :: Color -> Gtk.Render ()
renderColor (Color r g b) = setSourceRGB  r' g' b'
  where
    (r', g', b') = (fromIntegral r / denom,
                    fromIntegral g / denom,
                    fromIntegral b / denom) :: (Double, Double, Double)
    denom = 65535 :: Double
--    rgb = toSRGB k
--    (r, g, b) = (channelRed rgb, channelGreen rgb, channelBlue rgb)


drawNode :: Color -> GramState -> GraphEditState -> G.NodeId -> Render ()
drawNode color state gstate n =
    case p of
        Just ((x, y), rF, cF) -> do
            setLineWidth defLineWidth
            renderColor defBorderColor
            Gtk.arc x y defRadius 0 $ 2 * pi
            strokePreserve
            renderColor color
            if sel then fillPreserve >> highlight >> fill else fill
            return ()
        otherwise -> return ()
  where
    highlight = setSourceRGBA 0 0 0 0.4
    p = G.nodePayload (_getGraph gstate) n
    sel = Node n (fromJust p) `elem` get selObjects gstate

nodeRenderType :: GramState -> GraphEditState -> G.NodeId -> Render ()
nodeRenderType state gstate n =
    case newP of
        Just (_, rF, _) -> rF state gstate n
        _ -> return ()
  where
    nodeTypes = R.apply (_getNodeRelation gstate) n
    tGraph = get (getGraph . getTypeGraph) state
    newP = case nodeTypes of
               (x:xs) -> G.nodePayload tGraph x
               _ -> Nothing

directionVect :: Coords -> Coords -> Coords
directionVect s@(x, y) t@(x', y')
    | dist == 0 = (-1, 1)
    | otherwise = (dx / dist, dy / dist)
  where 
    dist = norm s t
    dx = x' - x
    dy = y' - y

norm :: Coords -> Coords -> Double
norm (x, y) (x', y') =
    sqrt $ (square (x' - x)) + (square (y' - y))
  where
    square x = x * x

angle :: Coords -> Double
angle (dx, dy)
    | dx == 0 && dy >= 0 = pi / 2
    | dx == 0 && dy < 0  = (-pi) / 2
    | dx >= 0 = ang
    | dx < 0 = ang - pi
  where
    ang = atan $ dy / dx

edgeCenter :: Coords -> Coords -> Double -> Coords
edgeCenter src@(x, y) tgt@(x', y') bendFactor =
    ( x + dx * dist / 2 - dy * defRadius * bendFactor
    , y + dy * dist / 2 + dx * defRadius * bendFactor )
  where
    (dx, dy) = directionVect src tgt
    dist = norm src tgt