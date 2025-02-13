{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "cardano-transaction-lib"
, dependencies =
  [ "aeson"
  , "aeson-helpers"
  , "aff"
  , "aff-promise"
  , "affjax"
  , "arraybuffer-types"
  , "arrays"
  , "bifunctors"
  , "bigints"
  , "checked-exceptions"
  , "console"
  , "const"
  , "contravariant"
  , "control"
  , "datetime"
  , "debug"
  , "effect"
  , "either"
  , "encoding"
  , "enums"
  , "exceptions"
  , "foldable-traversable"
  , "foreign-object"
  , "http-methods"
  , "identity"
  , "integers"
  , "js-date"
  , "lattice"
  , "lists"
  , "maybe"
  , "medea"
  , "media-types"
  , "monad-logger"
  , "mote"
  , "newtype"
  , "node-buffer"
  , "node-fs"
  , "node-fs-aff"
  , "node-path"
  , "node-process"
  , "nonempty"
  , "now"
  , "numbers"
  , "ordered-collections"
  , "orders"
  , "parallel"
  , "partial"
  , "prelude"
  , "profunctor"
  , "profunctor-lenses"
  , "quickcheck"
  , "quickcheck-combinators"
  , "quickcheck-laws"
  , "rationals"
  , "record"
  , "refs"
  , "spec"
  , "spec-quickcheck"
  , "strings"
  , "tailrec"
  , "text-encoding"
  , "these"
  , "transformers"
  , "tuples"
  , "typelevel"
  , "typelevel-prelude"
  , "uint"
  , "undefined"
  , "unfoldable"
  , "untagged-union"
  , "variant"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs", "examples/**/*.purs" ]
}
