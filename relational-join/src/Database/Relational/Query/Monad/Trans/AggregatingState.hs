{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      : Database.Relational.Query.Monad.Trans.AggregatingState
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module provides state definition for
-- "Database.Relational.Query.Monad.Trans.Aggregating".
module Database.Relational.Query.Monad.Trans.AggregatingState (
  -- * Context of aggregated query
  AggregatingContext,

  primeAggregatingContext,

  addGroupBy, addRestriction,

  aggregateRestriction, aggregateTerms,

  composeGroupBys
  ) where

import Data.DList (DList)
import qualified Data.DList as DList
import Data.Monoid ((<>))
import Control.Applicative (pure)

import Database.Relational.Query.Context (Aggregated)
import Database.Relational.Query.Expr (Expr, fromJust, exprAnd)
import Database.Relational.Query.Expr.Unsafe (showExpr)
import Database.Relational.Query.Sub (AggregateTerm, AggregateTerms, AggregatedQueryRestriction)

import Language.SQL.Keyword (Keyword(..), unwordsSQL)
import qualified Language.SQL.Keyword as SQL
import qualified Language.SQL.Keyword.ConcatString as SQLs


-- | Context state of aggregated query.
data AggregatingContext =
  AggregatingContext
  { groupByTerms :: DList AggregateTerm
  , restriction  :: AggregatedQueryRestriction
  }

-- | Initial value of 'AggregatingContext'.
primeAggregatingContext :: AggregatingContext
primeAggregatingContext =  AggregatingContext DList.empty Nothing

-- | Add group by term into 'AggregatingContext'.
addGroupBy :: String -> AggregatingContext -> AggregatingContext
addGroupBy t c =  c { groupByTerms = groupByTerms c <> pure t }

-- | Add having restriction into 'AggregatingContext'.
addRestriction :: Expr Aggregated (Maybe Bool) -> AggregatingContext -> AggregatingContext
addRestriction e1 ctx =
  ctx { restriction = Just . uf . restriction $ ctx }
  where uf  Nothing  = fromJust e1
        uf (Just e0) = e0 `exprAnd` fromJust e1

-- | Finalize context to extract accumulated aggregate restriction state.
aggregateRestriction :: AggregatingContext -> AggregatedQueryRestriction
aggregateRestriction = restriction

-- | Finalize context to extract accumulated aggregate terms state.
aggregateTerms :: AggregatingContext -> AggregateTerms
aggregateTerms =  DList.toList . groupByTerms

-- | Extract 'AggregatingContext' into SQL string.
composeGroupBys :: AggregatingContext -> String
composeGroupBys ac = unwordsSQL $ groupBys ++ havings
  where groupBys
          | null gs   = []
          | otherwise = [GROUP, BY, SQL.word . concat $ gs `SQLs.sepBy` ", "]
        gs = DList.toList (groupByTerms ac)
        havings = maybe [] (\e -> [HAVING, SQL.word . showExpr $ e]) $ restriction ac
