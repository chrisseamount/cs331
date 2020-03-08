-- parseit.lua
-- Christopher Seamount
-- 2020-03-06
--
-- For CS 331 Spring 2020
-- Parser for Degu language
-- Requires lexit.lua


-- Grammar
-- Start symbol: program
--
--     program 	    ->  stmt_list
--     stmt_list    ->  { statement }
--     statement 	->  ‘print’ ‘(’ [ print_arg { ‘,’ print_arg } ] ‘)’
--                   |  ‘func’ ID ‘(’ ‘)’ stmt_list ‘end’
--                   |  ‘if’ expr stmt_list { ‘elif’ expr stmt_list } [ ‘else’ stmt_list ] ‘end’
--                   |  ‘while’ expr stmt_list ‘end’
--                   |  ‘return’ expr
--                   |  ID ( ‘(’ ‘)’ | [ ‘[’ expr ‘]’ ] ‘=’ expr )
--     print_arg 	->  STRLIT
--                   |  ‘char’ ‘(’ expr ‘)’
--                   |  expr
--     expr 	    ->  comp_expr { ( ‘and’ | ‘or’ ) comp_expr }
--     comp_expr 	->  arith_expr { ( ‘==’ | ‘!=’ | ‘<’ | ‘<=’ | ‘>’ | ‘>=’ ) arith_expr }
--     arith_expr 	->  term { ( ‘+’ | ‘-’ ) term }
--     term 	    ->  factor { ( ‘*’ | ‘/’ | ‘%’ ) factor }
--     factor 	    ->  ‘(’ expr ‘)’
--                   |  ( ‘+’ | ‘-’ | ‘not’ ) factor
--                   |  NUMLIT
--                   |  ( ‘true’ | ‘false’ )
--                   |  ‘input’ ‘(’ ‘)’
--                   |  ID [ ‘(’ ‘)’ | ‘[’ expr ‘]’ ]
--

lexit = require "lexit" -- import lexit module

-- *********************************************************************
-- Module Table Initialization
-- *********************************************************************

local parseit = {}   -- Our module; members are added below

-- *********************************************************************
-- Constants
-- *********************************************************************

-- Symbolic Constants for AST

local STMT_LIST   = 1
local PRINT_STMT  = 2
local FUNC_DEF    = 3
local FUNC_CALL   = 4
local IF_STMT     = 5
local WHILE_STMT  = 6
local RETURN_STMT = 7
local ASSN_STMT   = 8
local STRLIT_OUT  = 9
local CHAR_CALL   = 10
local BIN_OP      = 11
local UN_OP       = 12
local NUMLIT_VAL  = 13
local BOOLLIT_VAL = 14
local INPUT_CALL  = 15
local SIMPLE_VAR  = 16
local ARRAY_VAR   = 17

-- *********************************************************************
-- Variables
-- *********************************************************************

-- For lexit iteration
local iter          -- Iterator returned by lexit.lex
local state         -- State for above iterator (maybe not used)
local lexit_out_s   -- Return value #1 from above iterator
local lexit_out_c   -- Return value #2 from above iterator

-- For current lexeme
local lexstr = ""   -- String form of current lexeme
local lexcat = 0    -- Category of current lexeme:
                    --  one of categories above, or 0 for past the end


-- *********************************************************************
-- Utility Functions
-- *********************************************************************

-- advance
-- Go to next lexeme and load it into lexstr, lexcat.
-- Should be called once before any parsing is done.
-- Function init must be called before this function is called.
local function advance()
    -- Advance the iterator
    lexit_out_s, lexit_out_c = iter(state, lexit_out_s)

    -- If we're not past the end, copy current lexeme into vars
    if lexit_out_s ~= nil then
        lexstr, lexcat = lexit_out_s, lexit_out_c
    else
        lexstr, lexcat = "", 0
    end
end


-- init
-- Initial call. Sets input for parsing functions.
local function init(prog)
    iter, state, lexit_out_s = lexit.lex(prog)
    advance()
end


-- atEnd
-- Return true if pos has reached end of input.
-- Function init must be called before this function is called.
local function atEnd()
    return lexcat == 0
end


-- matchString
-- Given string, see if current lexeme string form is equal to it. If
-- so, then advance to next lexeme & return true. If not, then do not
-- advance, return false.
-- Function init must be called before this function is called.
local function matchString(s)
    if lexstr == s then
        advance()
        return true
    else
        return false
    end
end


-- matchCat
-- Given lexeme category (integer), see if current lexeme category is
-- equal to it. If so, then advance to next lexeme & return true. If
-- not, then do not advance, return false.
-- Function init must be called before this function is called.
local function matchCat(c)
    if lexcat == c then
        advance()
        return true
    else
        return false
    end
end

-- *********************************************************************
-- The Parser
-- *********************************************************************

-- parse
-- Given program, initialize parser and call parsing function for start
-- symbol. Returns pair of booleans & AST. First boolean indicates
-- successful parse or not. Second boolean indicates whether the parser
-- reached the end of the input or not. AST is only valid if first
-- boolean is true.
function parseit.parse(prog)
    -- Initialization
    init(prog)

    -- Get results from parsing
    local good, ast = parse_program()  -- Parse start symbol
    local done = atEnd()

    -- And return them
    return good, done, ast
end

-- parse_program
-- Parsing function for nonterminal "program".
-- Function init must be called before this function is called.
function parse_program()
    local good, ast

    good, ast = parse_stmt_list()
    return good, ast
end


-- parse_stmt_list
-- Parsing function for nonterminal "stmt_list".
-- Function init must be called before this function is called.
function parse_stmt_list()
    local good, ast, newast

    ast = { STMT_LIST }
    while true do
        if lexstr ~= "print"
          and lexstr ~= "func"
          and lexstr ~= "if"
          and lexstr ~= "while"
          and lexstr ~= "return"
          and lexcat ~= lexit.ID then
            return true, ast
        end

        good, newast = parse_statement()
        if not good then
            return false, nil
        end

        table.insert(ast, newast)
    end
end


-- parse_statement
-- Parsing function for nonterminal "statement".
-- Function init must be called before this function is called.
function parse_statement()
    local good, ast1, ast2, ast3, savelex

    savelex = lexstr

    -- print
    if matchString("print") then
        if not matchString("(") then
            return false, nil
        end

        if matchString(")") then
            return true, { PRINT_STMT }
        end

        good, ast1 = parse_print_arg()
        if not good then
            return false, nil
        end

        ast2 = { PRINT_STMT, ast1 }

        while matchString(",") do
            good, ast1 = parse_print_arg()
            if not good then
                return false, nil
            end

            table.insert(ast2, ast1)
        end

        if not matchString(")") then
            return false, nil
        end

        return true, ast2

    -- function definition
    elseif matchString("func") then
        savelex = lexstr
        if not matchCat(lexit.ID) then
            return false, nil
        end

        if matchString("(") then
            if matchString(")") then
                good, ast1 = parse_stmt_list()
                if not good then
                    return false, nil
                end
            else
                return false, nil
            end
        else
            return false, nil
        end

        if not matchString("end") then
            return false, nil
        end

        return true, { FUNC_DEF, savelex, ast1 }

    -- if
    elseif matchString("if") then

        good, ast1 = parse_expr()
        if not good then
            return false, nil
        end

        good, ast2 = parse_stmt_list()
        if not good then
            return false, nil
        end

        ast3 = { IF_STMT, ast1, ast2 }

        while matchString("elif") do
            good, ast1 = parse_expr()
            if not good then
                return false, nil
            end

            good, ast2 = parse_stmt_list()
            if not good then
                return false, nil
            end

            table.insert(ast3, ast1)
            table.insert(ast3, ast2)
        end

        if matchString("else") then
            good, ast2 = parse_stmt_list()
            if not good then
                return false, nil
            end

            table.insert(ast3, ast2)
        end

        if not matchString("end") then
            return false, nil
        end

        return true, ast3
        

    -- while
    elseif matchString("while") then
        good, ast1 = parse_expr()
        if not good then
            return false, nil
        end

        good, ast2 = parse_stmt_list()
        if not good then
            return false, nil
        end

        if not matchString("end") then
            return false, nil
        end

        return true, { WHILE_STMT, ast1, ast2 }

    -- return
    elseif matchString("return") then
        good, ast1 = parse_expr()
        if not good then
            return false, nil
        end

        return true, { RETURN_STMT, ast1 }

    -- beginning with identifier
    elseif matchCat(lexit.ID) then
        if matchString("(") then
            if matchString(")") then
                return true, {FUNC_CALL, savelex}
            end
            return false, nil
        end

        if matchString("[") then
            ast2 = { ARRAY_VAR, savelex }
            good, ast1 = parse_expr()
            if not good then
                return false, nil
            end
            if matchString("]") then
                table.insert(ast2, ast1)
            else
                return false, nil
            end
        else
            ast2 = { SIMPLE_VAR, savelex }
        end

        if not matchString("=") then
            return false, nil
        end

        good, ast1 = parse_expr()
        if not good then
            return false, nil
        end

        return true, { ASSN_STMT, ast2, ast1 }

    end

    return false, nil

end

-- parse_print_arg
-- Parsing function for nonterminal "print_arg".
-- Function init must be called before this function is called.
function parse_print_arg()
    local savelex, good, ast

    -- string literal
    savelex = lexstr
    if matchCat(lexit.STRLIT) then
        return true, { STRLIT_OUT, savelex }
    end

    -- character code
    if matchString("char") then
        if matchString("(") then
            good, ast1 = parse_expr()
            if not good then
                return false, nil
            end
            if not matchString(")") then
                return false, nil
            end
            return true, { CHAR_CALL, ast1 }
        end
    end

    -- expression
    return parse_expr()
end

-- parse_expr
-- Parsing function for nonterminal "expr".
-- Function init must be called before this function is called.
function parse_expr()
    local good, ast1, ast2, savelex

    good, ast1 = parse_comp_expr()
    if not good then
        return false, nil
    end

    savelex = lexstr

    while matchString("or") or matchString("and") do
        good, ast2 = parse_comp_expr()
        if not good then
            return false, nil
        end

        ast1 = { { BIN_OP, savelex }, ast1, ast2 }
        savelex = lexstr
    end

    return true, ast1

end

-- parse_comp_expr
-- Parsing function for nonterminal "comp_expr".
-- Function init must be called before this function is called.
function parse_comp_expr()
    local good, ast1, ast2, savelex

    good, ast1 = parse_arith_exper()
    if not good then
        return false, nil
    end

    savelex = lexstr

    while matchString("==") or matchString("!=") or
          matchString("<") or matchString("<=") or
          matchString(">") or matchString(">=") do
    
        good, ast2 = parse_arith_exper()
        if not good then
            return false, nil
        end

        ast1 = { { BIN_OP, savelex }, ast1, ast2 }
        savelex = lexstr
    end

    return true, ast1

end

-- parse_arith_exper
-- Parsing function for nonterminal "arith_expr".
-- Function init must be called before this function is called.
function parse_arith_exper()
    local good, ast1, ast2, savelex

    good, ast1 = parse_term()
    if not good then
        return false, nil
    end

    savelex = lexstr

    while matchString("+") or matchString("-") do
        good, ast2 = parse_term()
        if not good then
            return false, nil
        end

        ast1 = { { BIN_OP, savelex }, ast1, ast2 }
        savelex = lexstr
    end

    return true, ast1

end

-- parse_term
-- Parsing function for nonterminal "term".
-- Function init must be called before this function is called.
function parse_term()
    local good, ast1, ast2, savelex

    good, ast1 = parse_factor()
    if not good then
        return false, nil
    end

    savelex = lexstr

    while matchString("*") or matchString("/") or
          matchString("%") do
        good, ast2 = parse_factor()
        if not good then
            return false, nil
        end

        ast1 = { { BIN_OP, savelex }, ast1, ast2 }
        savelex = lexstr
    end

    return true, ast1

end

-- parse_factor
-- Parsing function for nonterminal "factor".
-- Function init must be called before this function is called.
function parse_factor()
    local good, ast1, ast2, savelex

    savelex = lexstr

    -- parenthesized expression
    if matchString("(") then
        good, ast1 = parse_expr()
        if not good then
            return false, nil
        end

        if not matchString(")") then
            return false, nil
        end

        return true, ast1

    -- unary operator
    elseif matchString("+") or matchString("-") or 
           matchString("not") then
        good, ast1 = parse_factor()
        if not good then
            return false, nil
        end

        return true, { { UN_OP, savelex }, ast1 }

    -- numeric literal
    elseif matchCat(lexit.NUMLIT) then
        return true, { NUMLIT_VAL, savelex }

    -- boolean literal
    elseif matchString("true") or matchString("false") then
        return true, { BOOLLIT_VAL, savelex }

    -- input
    elseif matchString("input") then
        if matchString("(") then
            if matchString(")") then
                return true, { INPUT_CALL }
            end
        end
        return false, nil

    -- beginning with identifier
    elseif matchCat(lexit.ID) then
        if matchString("(") then
            if matchString(")") then
                return true, { FUNC_CALL, savelex }
            else
                return false, nil
            end
        end

        if matchString("[") then
            good, ast1 = parse_expr()
            if not good then
                return false, nil
            end
            if matchString("]") then
                return true, { ARRAY_VAR, savelex, ast1 }
            else
                return false, nil
            end
        end

        return true, { SIMPLE_VAR, savelex }

    end
end

-- *********************************************************************
-- Module Table Return
-- *********************************************************************

return parseit