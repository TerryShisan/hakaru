{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Main where

import Language.Hakaru.Parser.Parser hiding (style)
import Language.Hakaru.Parser.SymbolResolve (resolveAST)
import Language.Hakaru.Syntax.TypeCheck

import           Language.Hakaru.Syntax.ABT
import qualified Language.Hakaru.Syntax.AST as T

import HKC.CodeGen

import           Data.Text
import qualified Data.Text.IO as IO

import System.Environment

main :: IO ()
main = do
  args   <- getArgs
  progs  <- mapM readFromFile args
  case progs of
      [prog] -> compileHakaru prog
      _      -> IO.putStrLn "Usage: hkc <input> <output>"

readFromFile :: String -> IO Text
readFromFile "-" = IO.getContents
readFromFile x   = IO.readFile x


-- TODO: parseAndInfer has been copied to hkc, compile, and hakaru commands
parseAndInfer :: Text
              -> Either String (TypedAST (TrivialABT T.Term))
parseAndInfer x =
    case parseHakaru x of
    Left  err  -> Left (show err)
    Right past ->
        let m = inferType (resolveAST past) in
        runTCM m LaxMode

compileHakaru :: Text -> IO ()
compileHakaru prog =
  case parseAndInfer prog of
    Left err -> putStrLn $ show err
    Right t@(TypedAST _ ast) -> do
      IO.putStrLn "\n<===================================================>\n"
      IO.putStrLn $ pack $ show ast
      IO.putStrLn "\n<===================================================>\n"
      IO.putStrLn $ createProgram t
