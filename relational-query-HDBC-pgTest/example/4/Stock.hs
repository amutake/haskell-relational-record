{-# LANGUAGE TemplateHaskell, MultiParamTypeClasses, FlexibleInstances #-}

module Stock where

import Prelude hiding (seq)
import PgTestDataSource (defineTable)
import Database.Record.TH (derivingShow)

$(defineTable []
  "EXAMPLE4" "stock" [derivingShow])
