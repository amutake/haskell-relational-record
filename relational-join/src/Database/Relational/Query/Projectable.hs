{-# LANGUAGE FlexibleInstances #-}
-- |
-- Module      : Database.Relational.Query.Projectable
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines operators on various polymorphic projections.
module Database.Relational.Query.Projectable (
  -- * Conversion between individual Projections
  expr,

  -- * Projectable from SQL strings
  SqlProjectable (unsafeProjectSqlTerms), unsafeProjectSql,

  -- * Projections of values
  value,
  valueTrue, valueFalse,
  values,
  unsafeValueNull,

  -- * Placeholders
  PlaceHolders, addPlaceHolders, unsafePlaceHolders,
  placeholder', placeholder,

  -- * Projectable into SQL strings
  unsafeShowSqlExpr,
  unsafeShowSqlProjection,
  ProjectableShowSql (unsafeShowSql),

  -- * Binary Operators
  SqlBinOp,
  unsafeBinOp,

  (.=.), (.<.), (.<=.), (.>.), (.>=.), (.<>.),

  in', and', or',

  isNull, isNotNull, not', exists,

  (.||.), (?||?),
  (.+.), (.-.), (./.), (.*.),
  (?+?), (?-?), (?/?), (?*?),

  -- * Zipping projections
  ProjectableZip (projectZip), (><),
  ProjectableIdZip (..),

  -- * 'Maybe' type projecitoins
  ProjectableMaybe (just, flattenMaybe)
  ) where

import Prelude hiding (pi)

import Data.String (IsString)
import Control.Applicative ((<$>))

import qualified Language.SQL.Keyword as SQL
import qualified Language.SQL.Keyword.ConcatString as SQLs

import Database.Record (PersistableWidth, PersistableRecordWidth, derivedWidth)

import Database.Relational.Query.Internal.String (paren, sqlRowString)
import Database.Relational.Query.Context (Flat, Aggregated, Exists)
import Database.Relational.Query.Component (columnSQL, stringFromColumnSQL)
import Database.Relational.Query.Expr (Expr, ShowConstantSQL (showConstantSQL))
import qualified Database.Relational.Query.Expr as Expr
import qualified Database.Relational.Query.Expr.Unsafe as UnsafeExpr

import Database.Relational.Query.Pi (Pi, piZip)

import Database.Relational.Query.Projection
  (Projection, unsafeFromColumns, columns,
   ListProjection, unsafeShowSqlListProjection)
import qualified Database.Relational.Query.Projection as Projection


-- | Unsafely get SQL term from 'Proejction'.
unsafeShowSqlProjection :: Projection c r -> String
unsafeShowSqlProjection =  sqlRowString . map stringFromColumnSQL . columns

-- | 'Expr' from 'Projection'
exprOfProjection :: Projection c r -> Expr c r
exprOfProjection =  UnsafeExpr.Expr . unsafeShowSqlProjection

-- | Project from Projection type into expression type.
expr :: Projection p a -> Expr p a
expr =  exprOfProjection


-- | Unsafely generate 'Projection' from SQL expression strings.
unsafeSqlTermsProjection :: [String] -> Projection c t
unsafeSqlTermsProjection =  unsafeFromColumns . map columnSQL

-- | Interface to project SQL terms unsafely.
class SqlProjectable p where
  -- | Unsafely project from SQL expression strings.
  unsafeProjectSqlTerms :: [String] -- ^ SQL expression strings
                        -> p t      -- ^ Result projection object

-- | Unsafely make 'Projection' from SQL terms.
instance SqlProjectable (Projection Flat) where
  unsafeProjectSqlTerms = unsafeSqlTermsProjection

-- | Unsafely make 'Projection' from SQL terms.
instance SqlProjectable (Projection Aggregated) where
  unsafeProjectSqlTerms = unsafeSqlTermsProjection

-- | Unsafely make 'Expr' from SQL terms.
instance SqlProjectable (Expr p) where
  unsafeProjectSqlTerms = UnsafeExpr.Expr . sqlRowString

-- | Unsafely Project single SQL term.
unsafeProjectSql :: SqlProjectable p => String -> p t
unsafeProjectSql =  unsafeProjectSqlTerms . (:[])

-- | Polymorphic projection of SQL null value.
unsafeValueNull :: SqlProjectable p => p (Maybe a)
unsafeValueNull =  unsafeProjectSql "NULL"

-- | Generate polymorphic projection of SQL constant values from Haskell value.
value :: (ShowConstantSQL t, SqlProjectable p) => t -> p t
value =  unsafeProjectSql . showConstantSQL

-- | Polymorphic proejction of SQL true value.
valueTrue  :: (SqlProjectable p, ProjectableMaybe p) => p (Maybe Bool)
valueTrue  =  just $ value True

-- | Polymorphic proejction of SQL false value.
valueFalse :: (SqlProjectable p, ProjectableMaybe p) => p (Maybe Bool)
valueFalse =  just $ value False

-- | Polymorphic proejction of SQL set value from Haskell list.
values :: (SqlProjectable p, ShowConstantSQL t) => [t] -> ListProjection p t
values =  Projection.list . map value


-- | Interface to get SQL term from projections.
class ProjectableShowSql p where
  -- | Unsafely generate SQL expression string from projection object.
  unsafeShowSql :: p a    -- ^ Source projection object
                -> String -- ^ Result SQL expression string.

-- | Unsafely get SQL term from 'Expr'.
unsafeShowSqlExpr :: Expr p t -> String
unsafeShowSqlExpr =  UnsafeExpr.showExpr

-- | Unsafely get SQL term from 'Expr'.
instance ProjectableShowSql (Expr p) where
  unsafeShowSql = unsafeShowSqlExpr

-- | Unsafely get SQL term from 'Proejction'.
instance ProjectableShowSql (Projection c) where
  unsafeShowSql = unsafeShowSqlProjection


-- | Binary operator type for SQL String.
type SqlBinOp = String -> String -> String

-- | Binary operator from SQL operator string.
sqlBinOp :: String -> SqlBinOp
sqlBinOp =  SQLs.defineBinOp . SQL.word

-- | Unsafely make projection unary operator from SQL keyword.
unsafeUniOp :: (SqlProjectable p, ProjectableShowSql p)
            => SQL.Keyword -> p a -> p b
unsafeUniOp kw = unsafeProjectSql . paren . SQLs.defineUniOp kw . unsafeShowSql

-- | Unsafely make projection binary operator from string binary operator.
unsafeBinOp :: (SqlProjectable p, ProjectableShowSql p)
            => SqlBinOp
            -> p a -> p b -> p c
unsafeBinOp op a b = unsafeProjectSql . paren
                     $ op (unsafeShowSql a) (unsafeShowSql b)

-- | Unsafely make compare projection binary operator from string binary operator.
compareBinOp :: (SqlProjectable p, ProjectableShowSql p)
             => SqlBinOp
             -> p a -> p a -> p (Maybe Bool)
compareBinOp =  unsafeBinOp

-- | Unsafely make number projection binary operator from string binary operator.
monoBinOp :: (SqlProjectable p, ProjectableShowSql p)
         => SqlBinOp
         -> p a -> p a -> p a
monoBinOp =  unsafeBinOp


-- | Compare operator corresponding SQL /=/ .
(.=.)  :: (SqlProjectable p, ProjectableShowSql p)
  => p ft -> p ft -> p (Maybe Bool)
(.=.)  =  compareBinOp (SQLs..=.)

-- | Compare operator corresponding SQL /</ .
(.<.)  :: (SqlProjectable p, ProjectableShowSql p)
  => p ft -> p ft -> p (Maybe Bool)
(.<.)  =  compareBinOp (SQLs..<.)

-- | Compare operator corresponding SQL /<=/ .
(.<=.)  :: (SqlProjectable p, ProjectableShowSql p)
  => p ft -> p ft -> p (Maybe Bool)
(.<=.)  =  compareBinOp (SQLs..<=.)

-- | Compare operator corresponding SQL />/ .
(.>.)  :: (SqlProjectable p, ProjectableShowSql p)
  => p ft -> p ft -> p (Maybe Bool)
(.>.)  =  compareBinOp (SQLs..>.)

-- | Compare operator corresponding SQL />=/ .
(.>=.)  :: (SqlProjectable p, ProjectableShowSql p)
  => p ft -> p ft -> p (Maybe Bool)
(.>=.)  =  compareBinOp (SQLs..>=.)

-- | Compare operator corresponding SQL /<>/ .
(.<>.) :: (SqlProjectable p, ProjectableShowSql p)
  => p ft -> p ft -> p (Maybe Bool)
(.<>.) =  compareBinOp (SQLs..<>.)

-- | Logical operator corresponding SQL /AND/ .
and' :: (SqlProjectable p, ProjectableShowSql p)
     => p ft -> p ft -> p (Maybe Bool)
and' =  compareBinOp SQLs.and

-- | Logical operator corresponding SQL /OR/ .
or' :: (SqlProjectable p, ProjectableShowSql p)
    => p ft -> p ft -> p (Maybe Bool)
or'  =  compareBinOp SQLs.or

-- | Logical operator corresponding SQL /NOT/ .
not' :: (SqlProjectable p, ProjectableShowSql p)
    => p (Maybe Bool) -> p (Maybe Bool)
not' =  unsafeUniOp SQL.NOT

-- | Logical operator corresponding SQL /EXISTS/ .
exists :: (SqlProjectable p, ProjectableShowSql p)
       => ListProjection (Projection Exists) r -> p (Maybe Bool)
exists =  unsafeProjectSql . paren . SQLs.defineUniOp SQL.EXISTS
          . unsafeShowSqlListProjection unsafeShowSql

-- | Concatinate operator corresponding SQL /||/ .
(.||.) :: (SqlProjectable p, ProjectableShowSql p, IsString a)
       => p a -> p a -> p a
(.||.) =  unsafeBinOp (SQLs..||.)

-- | Concatinate operator corresponding SQL /||/ . Maybe type version.
(?||?) :: (SqlProjectable p, ProjectableShowSql p, IsString a)
       => p (Maybe a) -> p (Maybe a) -> p (Maybe a)
(?||?) =  unsafeBinOp (SQLs..||.)

-- | Unsafely make number projection binary operator from SQL operator string.
monoBinOp' :: (SqlProjectable p, ProjectableShowSql p)
          => String -> p a -> p a -> p a
monoBinOp' = monoBinOp . sqlBinOp

-- | Number operator corresponding SQL /+/ .
(.+.) :: (SqlProjectable p, ProjectableShowSql p, Num a)
  => p a -> p a -> p a
(.+.) =  monoBinOp' "+"

-- | Number operator corresponding SQL /-/ .
(.-.) :: (SqlProjectable p, ProjectableShowSql p, Num a)
  => p a -> p a -> p a
(.-.) =  monoBinOp' "-"

-- | Number operator corresponding SQL /// .
(./.) :: (SqlProjectable p, ProjectableShowSql p, Num a)
  => p a -> p a -> p a
(./.) =  monoBinOp' "/"

-- | Number operator corresponding SQL /*/ .
(.*.) :: (SqlProjectable p, ProjectableShowSql p, Num a)
  => p a -> p a -> p a
(.*.) =  monoBinOp' "*"

-- | Number operator corresponding SQL /+/ .
(?+?) :: (SqlProjectable p, ProjectableShowSql p, Num a)
  => p (Maybe a) -> p (Maybe a) -> p (Maybe a)
(?+?) =  monoBinOp' "+"

-- | Number operator corresponding SQL /-/ .
(?-?) :: (SqlProjectable p, ProjectableShowSql p, Num a)
  => p (Maybe a) -> p (Maybe a) -> p (Maybe a)
(?-?) =  monoBinOp' "-"

-- | Number operator corresponding SQL /// .
(?/?) :: (SqlProjectable p, ProjectableShowSql p, Num a)
  => p (Maybe a) -> p (Maybe a) -> p (Maybe a)
(?/?) =  monoBinOp' "/"

-- | Number operator corresponding SQL /*/ .
(?*?) :: (SqlProjectable p, ProjectableShowSql p, Num a)
  => p (Maybe a) -> p (Maybe a) -> p (Maybe a)
(?*?) =  monoBinOp' "*"

-- | Binary operator corresponding SQL /IN/ .
in' :: (SqlProjectable p, ProjectableShowSql p)
    => p t -> ListProjection p t -> p (Maybe Bool)
in' a lp = unsafeProjectSql . paren
           $ SQLs.in' (unsafeShowSql a) (unsafeShowSqlListProjection unsafeShowSql lp)

-- | Operator corresponding SQL /IS NULL/ .
isNull :: (SqlProjectable p, ProjectableShowSql p)
       => p (Maybe t) -> p (Maybe Bool)
isNull x = compareBinOp (SQLs.defineBinOp SQL.IS) x unsafeValueNull

-- | Operator corresponding SQL /NOT (... IS NULL)/ .
isNotNull :: (SqlProjectable p, ProjectableShowSql p)
          => p (Maybe t) -> p (Maybe Bool)
isNotNull =  not' . isNull

-- | Placeholder parameter type which has real parameter type arguemnt 'p'.
data PlaceHolders p = PlaceHolders

-- | Unsafely add placeholder parameter to queries.
addPlaceHolders :: Functor f => f a -> f (PlaceHolders p, a)
addPlaceHolders =  fmap ((,) PlaceHolders)

-- | Unsafely get placeholder parameter
unsafePlaceHolders :: PlaceHolders p
unsafePlaceHolders =  PlaceHolders

-- | Unsafely cast placeholder parameter type.
unsafeCastPlaceHolders :: PlaceHolders a -> PlaceHolders b
unsafeCastPlaceHolders PlaceHolders = PlaceHolders

unsafeProjectPlaceHolder' :: (PersistableWidth r, SqlProjectable p)
                               => (PersistableRecordWidth r, p r)
unsafeProjectPlaceHolder' =  unsafeProjectSqlTerms . (`replicate` "?") <$> derivedWidth

unsafeProjectPlaceHolder :: (PersistableWidth r, SqlProjectable p)
                               => p r
unsafeProjectPlaceHolder =  snd unsafeProjectPlaceHolder'

-- | Provide scoped placeholder and return its parameter object.
placeholder' :: (PersistableWidth t, SqlProjectable p) => (p t -> a) ->  (PlaceHolders t, a)
placeholder' f = (PlaceHolders, f $ unsafeProjectPlaceHolder)

-- | Provide scoped placeholder and return its parameter object. Monadic version.
placeholder :: (PersistableWidth t, SqlProjectable p, Monad m) => (p t -> m a) -> m (PlaceHolders t, a)
placeholder f = do
  let (ph, ma) = placeholder' f
  a <- ma
  return (ph, a)


-- | Interface to zip projections.
class ProjectableZip p where
  -- | Zip projections.
  projectZip :: p a -> p b -> p (a, b)

-- | Zip placeholder parameters.
instance ProjectableZip PlaceHolders where
  projectZip PlaceHolders PlaceHolders = PlaceHolders

-- | Zip 'Projection'.
instance ProjectableZip (Projection c) where
  projectZip = Projection.compose

-- | Zip 'Pi'
instance ProjectableZip (Pi a) where
  projectZip = piZip

-- | Binary operator the same as 'projectZip'.
(><) ::ProjectableZip p => p a -> p b -> p (a, b)
(><) = projectZip

-- | Interface to control 'Maybe' of phantom type in projections.
class ProjectableMaybe p where
  -- | Cast projection phantom type into 'Maybe'.
  just :: p a -> p (Maybe a)
  -- | Compose nested 'Maybe' phantom type on projection.
  flattenMaybe :: p (Maybe (Maybe a)) -> p (Maybe a)

-- | Control phantom 'Maybe' type in placeholder parameters.
instance ProjectableMaybe PlaceHolders where
  just         = unsafeCastPlaceHolders
  flattenMaybe = unsafeCastPlaceHolders

-- | Control phantom 'Maybe' type in projection type 'Projection'.
instance ProjectableMaybe (Projection c) where
  just         = Projection.just
  flattenMaybe = Projection.flattenMaybe

-- | Control phantom 'Maybe' type in SQL expression type 'Expr'.
instance ProjectableMaybe (Expr p) where
  just         = Expr.just
  flattenMaybe = Expr.fromJust

-- | Zipping except for identity element laws.
class ProjectableZip p => ProjectableIdZip p where
  leftId  :: p ((), a) -> p a
  rightId :: p (a, ()) -> p a

-- | Zipping except for identity element laws against placeholder parameter type.
instance ProjectableIdZip PlaceHolders where
  leftId  = unsafeCastPlaceHolders
  rightId = unsafeCastPlaceHolders


infixl 7 .*., ./., ?*?, ?/?
infixl 6 .+., .-., ?+?, ?-?
infixl 5 .||., ?||?
infix  4 .=., .<>., .>., .>=., .<., .<=., `in'`
infixr 3 `and'`
infixr 2 `or'`
infixl 1  ><
