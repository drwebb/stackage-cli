{-# LANGUAGE OverloadedStrings #-}

module Main where

import Filesystem
import Control.Applicative
import Control.Monad
import Stackage.CLI
import Options.Applicative (Parser)
import Options.Applicative.Builder (strArgument, metavar, value)
import Data.Monoid
import Network.HTTP.Client
import Network.HTTP.Types.Status (statusCode)
import qualified Data.ByteString.Lazy as LBS
import System.Exit (exitFailure)
import System.Environment (getArgs)
import Control.Exception

type Target = String

targetParser :: Parser Target
targetParser = strArgument mods where
  mods = (metavar "SNAPSHOT" <> value "lts")

toUrl :: Target -> String
toUrl t = "http://stackage.org/" <> t <> "/cabal.config"

downloadTarget :: Target -> IO LBS.ByteString
downloadTarget target = withManager defaultManagerSettings $ \manager -> do
  let url = toUrl target
  req <- parseUrl url
  let getResponseLbs = do
        response <- httpLbs req manager
        return $ responseBody response
  let handle404 (StatusCodeException s _ _)
        | statusCode s == 404 = do
            putStrLn $ "Invalid target: " <> target
            exitFailure
      handle404 e = throwIO e
  getResponseLbs `catch` handle404

initTarget :: Target -> IO ()
initTarget target = do
  configExists <- isFile "cabal.config"
  when configExists $ do
    putStrLn $ "Warning: cabal.config already exists"
    putStrLn $ "No action taken"
    exitFailure
  downloadTarget target >>= LBS.writeFile "cabal.config"

version :: String
version = "0.1"

header :: String
header = "Initializes cabal.config"

progDesc :: String
progDesc = header

main = do
  (target, ()) <- simpleOptions
    version
    header
    progDesc
    targetParser -- global parser
    (Left ())    -- subcommands
  initTarget target
