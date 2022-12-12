module Ctl.Internal.QueryM.ServerConfig
  ( Host
  , ServerConfig
  , defaultKupoServerConfig
  , defaultOgmiosWsConfig
  , defaultServerConfig
  , mkHttpUrl
  , mkServerUrl
  , mkWsUrl
  ) where

import Prelude

import Ctl.Internal.Helpers ((<</>>))
import Ctl.Internal.JsWebSocket (Url)
import Data.Maybe (Maybe(Just, Nothing), fromMaybe)
import Data.UInt (UInt)
import Data.UInt as UInt

type Host = String

type ServerConfig =
  { port :: UInt
  , host :: Host
  , secure :: Boolean
  , path :: Maybe String
  }

defaultServerConfig :: ServerConfig
defaultServerConfig =
  { port: UInt.fromInt 8081
  , host: "localhost"
  , secure: false
  , path: Nothing
  }

defaultOgmiosWsConfig :: ServerConfig
defaultOgmiosWsConfig =
  { port: UInt.fromInt 1337
  , host: "localhost"
  , secure: false
  , path: Nothing
  }

defaultKupoServerConfig :: ServerConfig
defaultKupoServerConfig =
  { port: UInt.fromInt 4008
  , host: "localhost"
  , secure: false
  , path: Just "kupo"
  }

mkHttpUrl :: ServerConfig -> Url
mkHttpUrl = mkServerUrl "http"

mkWsUrl :: ServerConfig -> Url
mkWsUrl = mkServerUrl "ws"

mkServerUrl :: String -> ServerConfig -> Url
mkServerUrl protocol cfg =
  (if cfg.secure then (protocol <> "s") else protocol)
    <> "://"
    <> cfg.host
    <> ":"
    <> UInt.toString cfg.port
      <</>> fromMaybe "" cfg.path
