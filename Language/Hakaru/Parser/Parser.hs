{-# LANGUAGE RankNTypes, GADTs, ExistentialQuantification,
             StandaloneDeriving, OverloadedStrings #-}
module Language.Hakaru.Parser.Parser where

import Prelude hiding (Real)

import Data.Functor        ((<$>), (<$))
import Control.Applicative (Applicative(..))
import qualified Control.Monad as M
import Data.Functor.Identity
import Data.Text hiding (foldr1, foldl, foldr, map)

import Text.Parsec hiding (Empty)
import Text.ParserCombinators.Parsec (chainl1)
import Text.Parsec.Combinator (eof)
import Text.Parsec.Text hiding (Parser())
import Text.Parsec.Indentation
import Text.Parsec.Indentation.Char
import qualified Text.Parsec.Indentation.Token as ITok

import qualified Text.Parsec.Expr as Ex
import qualified Text.Parsec.Token as Tok

import Language.Hakaru.Parser.AST
import Language.Hakaru.Syntax.DataKind

ops, names :: [String]

ops   = ["+","*","-",":","::", "<~","==", "=", "_"]
types = ["->"]
names = ["def","fn", "if","else","pi","inf",
         "return", "dirac", "match", "data"]

type Parser = ParsecT (IndentStream (CharIndentStream Text)) () Identity

style = ITok.makeIndentLanguageDef $ Tok.LanguageDef
    { Tok.commentStart    = ""
    , Tok.commentEnd      = ""
    , Tok.nestedComments  = True
    , Tok.identStart      = letter <|> char '_'
    , Tok.identLetter     = alphaNum <|> oneOf "_'"
    , Tok.opStart         = oneOf ":!#$%&*+./<=>?@\\^|-~"
    , Tok.opLetter        = oneOf ":!#$%&*+./<=>?@\\^|-~"
    , Tok.caseSensitive   = True
    , Tok.commentLine     = "#"
    , Tok.reservedOpNames = ops ++ types
    , Tok.reservedNames   = names
    }

lexer = ITok.makeTokenParser style

integer :: Parser Integer
integer = Tok.integer lexer

float :: Parser Double
float = Tok.float lexer

parens :: Parser a -> Parser a
parens = Tok.parens lexer . localIndentation Any

braces :: Parser a -> Parser a
braces = Tok.parens lexer . localIndentation Any

brackets :: Parser a -> Parser a
brackets = Tok.brackets lexer . localIndentation Any

commaSep :: Parser a -> Parser [a]
commaSep = Tok.commaSep lexer

semiSep :: Parser a -> Parser [a]
semiSep = Tok.semiSep lexer

semiSep1 :: Parser a -> Parser [a]
semiSep1 = Tok.semiSep1 lexer

identifier :: Parser Text
identifier = M.liftM pack $ Tok.identifier lexer

reserved :: String -> Parser ()
reserved = Tok.reserved lexer

reservedOp :: String -> Parser ()
reservedOp = Tok.reservedOp lexer

symbol :: Text -> Parser Text
symbol = M.liftM pack . Tok.symbol lexer . unpack

binop :: Text ->  AST' Text ->  AST' Text ->  AST' Text
binop s x y
    | s == "+"  = NaryOp Sum' x y
    | otherwise = Var s `App` x `App` y

binary s = Ex.Infix $ do
    reservedOp s
    return $ binop (pack s)

prefix s f = Ex.Prefix (reservedOp s >> return f)

table =
    [ [ prefix "+"  id]
    , [ binary "^"  Ex.AssocLeft]
    , [ binary "*"  Ex.AssocLeft
      , binary "/"  Ex.AssocLeft]
    , [ binary "+"  Ex.AssocLeft
      , binary "-"  Ex.AssocLeft]
    -- TODO: add "<", "<=", ">=", "/="
    -- TODO: do you *really* mean AssocLeft? Shouldn't they be non-assoc?
    , [ binary ">"  Ex.AssocLeft
      , binary "==" Ex.AssocLeft]]

unit_ :: Parser (AST' a)
unit_ = string "()" >> return Empty

int :: Parser Value'
int = do
    n <- integer
    return $
        if n < 0
        then Int (fromInteger n)
        else Nat (fromInteger n)

floating :: Parser Value'
floating = do
    sign <- option '+' (oneOf "+-")
    n <- float
    return $
        case sign of
        '-' -> Real (negate n)
        '+' -> Prob n

inf_ :: Parser (AST' Text)
inf_ = do
    s <- option '+' (oneOf "+-")
    reserved "inf";
    return $
        case s of
        '-' -> NegInfinity
        '+' -> Infinity

var :: Parser (AST' Text)
var = Var <$> identifier

pairs :: Parser (AST' Text)
pairs = foldr1 (binop "Pair") <$> parens (commaSep op_expr)

type_var :: Parser TypeAST'
type_var = TypeVar <$> identifier

type_app :: Parser TypeAST'
type_app = TypeApp <$> identifier <*> parens (commaSep type_expr)

type_fun :: Parser TypeAST'
type_fun =
    chainl1
        (try type_app <|> type_var)
        (TypeFun <$ reservedOp "->")

type_expr :: Parser TypeAST'
type_expr = try type_fun
        <|> try type_app
        <|> type_var

ann_expr :: Parser (AST' Text)
ann_expr = Ann <$> basic_expr <* reservedOp "::" <*> type_expr

pdat_expr :: Parser PDatum
pdat_expr = DV <$> identifier <*> parens (commaSep identifier)

pat_expr :: Parser Pattern'
pat_expr =  try (PData' <$> pdat_expr)
        <|> (PWild' <$ reservedOp "_")
        <|> (PVar' <$> identifier)


-- | Blocks are indicated by colons, and must be indented.
blockOfMany p = do
    reservedOp ":"
    localIndentation Gt (many $ absoluteIndentation p)


-- | Semiblocks are like blocks, but indentation is optional. Also,
-- there are only 'expr' semiblocks.
semiblockExpr = reservedOp ":" *> localIndentation Ge expr


-- | Pseudoblocks seem like semiblocks, but actually they aren't
-- indented.
--
-- TODO: do we actually want this in our grammar, or did we really
-- mean to use 'semiblockExpr' instead?
pseudoblockExpr = reservedOp ":" *> expr


branch_expr :: Parser (Branch' Text)
branch_expr = Branch' <$> pat_expr <*> pseudoblockExpr

match_expr :: Parser (AST' Text)
match_expr =
    reserved "match"
    *>  (Case
        <$> expr
        <*> blockOfMany branch_expr
        )

data_expr :: Parser (AST' Text)
data_expr =
    reserved "data"
    *>  (Data
        <$> identifier
        <*  parens (commaSep identifier) -- TODO: why throw them away?
        <*> blockOfMany (try type_app <|> type_var)
        )

op_factor :: Parser (AST' Text)
op_factor =     try (M.liftM UValue floating)
            <|> try inf_
            <|> try unit_
            <|> try (M.liftM UValue int)
            <|> try var
            <|> try pairs
            <|> parens expr

op_expr :: Parser (AST' Text)
op_expr = Ex.buildExpressionParser table op_factor

if_expr :: Parser (AST' Text)
if_expr =
    reserved "if"
    *>  (If
        <$> localIndentation Ge expr
        <*> semiblockExpr
        <*  reserved "else"
        <*> semiblockExpr
        )

lam_expr :: Parser (AST' Text)
lam_expr =
    reserved "fn"
    *>  (Lam
        <$> identifier
        <*> pseudoblockExpr
        )

bind_expr :: Parser (AST' Text)
bind_expr = Bind
    <$> identifier
    <*  reservedOp "<~"
    <*> expr
    <*> expr

let_expr :: Parser (AST' Text)
let_expr = Let
    <$> identifier
    <*  reservedOp "="
    <*> expr
    <*> expr

def_expr :: Parser (AST' Text)
def_expr = do
    reserved "def"
    name <- identifier
    (vars,varTyps) <- unzip <$> parens (commaSep defarg)
    bodyTyp <- optionMaybe type_expr
    body    <- semiblockExpr
    let body' = foldr Lam body vars
        typ   = foldr TypeFun <$> bodyTyp <*> sequence varTyps
    Let name (maybe id (flip Ann) typ body')
        <$> expr -- the \"rest\"; i.e., where the 'def' is in scope

defarg :: Parser (Text, Maybe TypeAST')
defarg = (,) <$> identifier <*> optionMaybe type_expr

call_expr :: Parser (AST' Text)
call_expr =
    foldl App
        <$> (Var <$> identifier)
        <*> parens (commaSep basic_expr)

return_expr :: Parser (AST' Text)
return_expr = do
    reserved "return" <|> reserved "dirac"
    Dirac <$> expr

basic_expr :: Parser (AST' Text)
basic_expr = try call_expr
         <|> try op_expr

expr :: Parser (AST' Text)
expr =  if_expr
    <|> return_expr
    <|> lam_expr
    <|> def_expr
    <|> try match_expr
    -- <|> try data_expr
    <|> try ann_expr
    <|> try let_expr
    <|> try bind_expr
    <|> try basic_expr

indentConfig :: Text -> IndentStream (CharIndentStream Text)
indentConfig =
    mkIndentStream 0 infIndentation True Ge . mkCharIndentStream

parseHakaru :: Text -> Either ParseError (AST' Text)
parseHakaru =
    runParser (expr <* eof) () "<input>" . indentConfig

withPos :: Parser (AST' a) -> Parser (AST' a)
withPos x = do
    s  <- getPosition
    x' <- x
    e  <- getPosition
    return $ WithMeta x' (Meta (s, e))
