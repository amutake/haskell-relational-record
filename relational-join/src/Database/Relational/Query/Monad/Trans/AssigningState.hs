-- |
-- Module      : Database.Relational.Query.Monad.Trans.AssigningState
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module provides context definition for
-- "Database.Relational.Query.Monad.Trans.Assigning".
module Database.Relational.Query.Monad.Trans.AssigningState (
  -- * Assigning context
  AssigningTerms,
  AssigningContext,

  AssignColumn, AssignTerm,

  primeAssigningContext,

  updateAssignments,

  assignments
  ) where

import Data.DList (DList)
import qualified Data.DList as DList
import Data.Monoid ((<>))
import Control.Applicative (pure)

import Database.Relational.Query.Component (AssignColumn, AssignTerm, Assignment, Assignments)


-- | Assigning terms.
type AssigningTerms = DList Assignment

-- | Context type for Assignings.
newtype AssigningContext = AssigningContext { assigningTerms :: AssigningTerms }

-- | Initial 'AssigningContext'
primeAssigningContext :: AssigningContext
primeAssigningContext =  AssigningContext DList.empty

-- | Add order-by term.
updateAssignments :: AssignColumn -> AssignTerm -> AssigningContext -> AssigningContext
updateAssignments col term ctx =
  ctx { assigningTerms = assigningTerms ctx <> pure (col, term)  }

-- | Finalize context to extract accumulated assignment pairs state.
assignments :: AssigningContext -> Assignments
assignments =  DList.toList . assigningTerms
