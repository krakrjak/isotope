{-|
Module      : Isotope.Parsers
Description : Parsers for chemical and condensed formulae.
Copyright   : Michael Thomas
License     : GPL-3
Maintainer  : Michael Thomas <Michaelt293@gmail.com>
Stability   : Experimental

This module provides parsers for element symbols as well molecular, empirical and
condensed formulae. In addition, QuasiQuoters are provided.
-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE FlexibleInstances #-}
module Isotope.Parsers (
    -- * Parsers
      elementSymbol
    , subFormula
    , molecularFormula
    , condensedFormula
    , mol
    , emp
    , con
    ) where

import Isotope.Base
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Lift
import Text.Megaparsec
import Text.Megaparsec.String
import qualified Text.Megaparsec.Lexer as L
import Data.String
import Data.List hiding (filter)
import Data.Map (Map)

-- | Parses an element symbol string.
elementSymbol :: Parser ElementSymbol
elementSymbol = read <$> choice (try . string <$> elementSymbolStrList)
    where elementList = show <$> elementSymbolList
          reverseLengthSort x y = length y `compare` length x
          elementSymbolStrList = sortBy reverseLengthSort elementList

-- | Parses an sub-formula (i.e., \"C2\").
subFormula :: Parser MolecularFormula
subFormula = do
    sym <- elementSymbol
    num <- optional L.integer
    return $ case num of
                  Nothing -> mkMolecularFormula [(sym, 1)]
                  Just num' -> mkMolecularFormula [(sym, fromIntegral num')]

-- | Parses a molecular formula (i.e. \"C6H6\").
molecularFormula :: Parser MolecularFormula
molecularFormula = do
    formulas <- many subFormula
    return $ mconcat formulas


-- Helper function. Parses parenthesed sections in condensed formulae, i.e.,
-- the \"(CH3)3\" section of \"N(CH3)3\".
parenFormula :: Parser (Either MolecularFormula ([MolecularFormula], Int))
parenFormula = do
   _ <- char '('
   formula <- some subFormula
   _ <- char ')'
   num <- optional L.integer
   return $ Right $ case num of
                         Nothing -> (formula, 1)
                         Just num' -> (formula, fromIntegral num')

-- Helper function. Parses non-parenthesed sections in condensed formulae, i.e.,
-- the \"N\" section of \"N(CH3)3\".
leftMolecularFormula :: Parser (Either MolecularFormula ([MolecularFormula], Int))
leftMolecularFormula = do
   formula <- subFormula
   return $ Left formula

-- | Parses a condensed formula, i.e., \"N(CH3)3\".
condensedFormula :: Parser CondensedFormula
condensedFormula = do
  result <- many (leftMolecularFormula <|> parenFormula)
  return $ CondensedFormula result

quoteMolecularFormula s =
    case parse (condensedFormula <* eof) "" s of
         Left err -> fail $ "Could not parse formula: " ++ show err
         Right v  -> lift $ toMolecularFormula v

quoteEmpiricalFormula s =
    case parse (condensedFormula <* eof) "" s of
         Left err -> fail $ "Could not parse formula: " ++ show err
         Right v  -> lift $ toEmpiricalFormula v

quoteCondensedFormula s =
    case parse (condensedFormula <* eof) "" s of
         Left err -> error $ "Could not parse formula: " ++ show err
         Right v  -> lift v

mol  :: QuasiQuoter
mol = QuasiQuoter
    { quoteExp = quoteMolecularFormula }

emp  :: QuasiQuoter
emp = QuasiQuoter
    { quoteExp = quoteEmpiricalFormula }

con  :: QuasiQuoter
con = QuasiQuoter
    { quoteExp = quoteCondensedFormula }

$(deriveLift ''MolecularFormula)

$(deriveLift ''EmpiricalFormula)

$(deriveLift ''CondensedFormula)

$(deriveLift ''Map)

$(deriveLift ''ElementSymbol)
