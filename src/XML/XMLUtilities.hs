{-# LANGUAGE Arrows, NoMonomorphismRestriction #-}

module XML.XMLUtilities
( atTag
, atTagCase
, text
, textAtTag
, parseHTML
, parseXML
)

where

import Text.XML.HXT.Core
import Data.Char

atTag tag = deep (isElem >>> hasName tag)

atTagCase tag = deep (isElem >>> hasNameWith ((== tag') . upper . localPart))
    where tag' = upper tag
          upper = map toUpper

text = getChildren >>> getText

textAtTag tag = atTag tag >>> text

parseHTML = readString [ withValidate no, withParseHTML yes, withWarnings no ]

parseXML file = readDocument [withValidate no, withRemoveWS yes] file
