{
module Parser.Parser (parseProg) where

import Language
import Parser.Lexer
}

%name parse1
%tokentype { Token }
%error { parseError }

%token
    int         { TokenInt $$ }
    name        { TokenName $$ }
    '['         { TokenSymb "[" }
    ']'         { TokenSymb "]" }
    '+'         { TokenSymb "+" }
    '-'         { TokenSymb "-" }
    '*'         { TokenSymb "*" }
    '/'         { TokenSymb "/" }
    '%'         { TokenSymb "%" }
    '('         { TokenSymb "(" }
    ')'         { TokenSymb ")" }
    
    '='         { TokenSymb "=" }
    "!="        { TokenSymb "!=" }
    "<="        { TokenSymb "<=" }
    ">="        { TokenSymb ">=" }
    '<'         { TokenSymb "<" }
    '>'         { TokenSymb ">" }
    '!'         { TokenSymb "!" }
    
    "||"        { TokenSymb "||" }
    "&&"        { TokenSymb "&&" }
    "==>"       { TokenSymb "==>" }
    ":="        { TokenSymb ":=" }
    ','         { TokenSymb "," }
    ';'         { TokenSymb ";" }
    "if"        { TIf }
    "then"      { TThen }
    "else"      { TElse }
    "end"       { TEnd }
    "while"     { TWhile }
    "do"        { TDo }
    "skip"      { TSkip }
    "program"   { TProgram }
    "is"        { TIs }

    "pre"       { TPre }
    "assert"    { TAssert }
    
    "forall"    { TForall }
    "exists"    { TExists }
    "true"      { TTrue }
    "false"     { TFalse }


%nonassoc "exists"
%nonassoc "forall"
%right "==>"
%left "||"
%left "&&"
%left '!'
%nonassoc '=' "!=" '>' '<' "<=" ">="
%left '+' '-'
%left '*' '/' '%'

%%

{- parameterized productions
   taken from https://www.haskell.org/happy/doc/html/sec-grammar.html -}

rev_list_plus(p)
     : p                    { [$1] }
     | rev_list_plus(p) p   { $2 : $1 }

{- non-empty lists of components, like "p+" -}
list_plus(p)
     : rev_list_plus(p)   { reverse $1 }

{- lists, like "p*" -}
list(p)
     : {- empty -}    { [] }
     | list_plus(p)   { $1 }

prog :: { Program }
     : "program" name '(' list(param) ')' list(pre) "is" stmtSeq "end"
       { Program{name = $2, param = $4, pre = $6, ast = $8} }

param :: {Typed}
     : name { ($1, TInt) }
     | name '['']' { ($1, TArr) }

pre  :: { Assertion }
     : "pre"  assertion   { $2 }
 
arithExp :: { AExp }
         : int { Num $1 }
         | name { Var ($1, TInt) }
         | '-' arithExp { BinOp Sub (Num 0) $2 }
         | name '[' arithExp ']' { Read (Var ($1, TArr)) $3 }
         | arithExp '+' arithExp { BinOp Add $1 $3 }
         | arithExp '-' arithExp { BinOp Sub $1 $3 }
         | arithExp '*' arithExp { BinOp Mul $1 $3 }
         | arithExp '/' arithExp { BinOp Div $1 $3 }
         | arithExp '%' arithExp { BinOp Mod $1 $3 }
         | '(' arithExp ')'      { $2 }
{-         | '(' arithExp ')'      { Parens $2 } -}

comp :: { Comparison }
     : arithExp '=' arithExp { Comp Eq $1 $3 }
     | arithExp '<' arithExp { Comp Lt $1 $3 }
     | arithExp '>' arithExp { Comp Gt $1 $3 }
     | arithExp "!=" arithExp { Comp Neq $1 $3 }
     | arithExp "<=" arithExp { Comp Le $1 $3 }
     | arithExp ">=" arithExp { Comp Ge $1 $3 }

boolExp :: { BExp }
        : comp { BCmp $1 }
        | '!' boolExp { BNot $2 }
        | boolExp "||" boolExp { BBinOp Or $1 $3 }
        | boolExp "&&" boolExp { BBinOp And $1 $3 }
        | '(' boolExp ')' { $2 }
        {- | '(' boolExp ')' { BParens $2 } -}

assertion :: { Assertion }
          : "true" { ATrue }
          | "false" { AFalse }
          | comp { ACmp $1 }
          | '!' assertion { ANot $2 }
          | assertion "==>" assertion { ABinOp Imply $1 $3 }
          | assertion "||" assertion { ABinOp Or $1 $3 }
          | assertion "&&" assertion { ABinOp And $1 $3 }
          | "forall" list_plus(name) ',' assertion { AQ Forall $2 $4 }
          | "exists" list_plus(name) ',' assertion { AQ Exists $2 $4 }
          | '(' assertion ')' { $2 }
          {- | '(' assertion ')' { AParens $2} -}

stmtSeq :: { AST }
        : stmt { $1 }
        | stmt stmtSeq { Seq $1 $2 }

stmt :: { AST }
     : name ":=" arithExp ';' { Assign $1 $3 }
     | name ',' name ":=" arithExp ',' arithExp ';' { ParAssign $1 $3 $5 $7 }
     | name '[' arithExp ']' ":=" arithExp ';' { Write $1 $3 $6 }
     | "if" boolExp "then" stmtSeq "else" stmtSeq "end" { If $2 $4 $6 }
     | "if" boolExp "then" stmtSeq "end" { If $2 $4 Skip }
     | "while" boolExp "do" stmtSeq "end" { While $2 $4 }
     | "skip" ';' { Skip }
     | "assert" assertion ';' {Assert $2}

{

parseProg = parse1 . lexProg

parseError :: [Token] -> a
parseError _ = error "Parse error"

}