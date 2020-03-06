-- parseit.lua
-- Glenn G. Chappell
-- 2020-02-14
--
-- For CS F331 / CSCE A331 Spring 2020
-- Recursive-Descent Parser #4: Expressions + Better ASTs
-- Requires lexit.lua


-- Grammar
-- Start symbol: expr
--
--     expr    ->  term { ("+" | "-") term }
--     term    ->  factor { ("*" | "/") factor }
--     factor  ->  ID
--              |  NUMLIT
--              |  "(" expr ")"
--
-- All operators (+ - * /) are left-associative.
--
-- AST Specification
-- - For an ID, the AST is { SIMPLE_VAR, SS }, where SS is the string
--   form of the lexeme.
-- - For a NUMLIT, the AST is { NUMLIT_VAL, SS }, where SS is the string
--   form of the lexeme.
-- - For expr -> term, then AST for the expr is the AST for the term,
--   and similarly for term -> factor.
-- - Let X, Y be expressions with ASTs XT, YT, respectively.
--   - The AST for ( X ) is XT.
--   - The AST for X + Y is { { BIN_OP, "+" }, XT, YT }. For multiple
--     "+" operators, left-asociativity is reflected in the AST. And
--     similarly for the other operators.


local parseit = {}  -- Our module

local lexit = require "lexit"


-- Variables

-- For current lexeme
local lexstr = ""   -- String form of current lexeme
local lexcat = 0    -- Category of current lexeme:
                    --  one of categories below, or 0 for past the end


-- Symbolic Constants for AST

local STMT_LIST = 1
local PRINT_STMT = 2
local FUNC_DEF = 3
local FUNC_CALL = 4
local IF_STMT = 5
local WHILE_STMT = 6
local RETURN_STMT = 7
local ASSN_STMT = 8
local STRLIT_OUT = 9
local CHAR_CALL = 10
local BIN_OP = 11
local UN_OP = 12
local NUMLIT_VAL = 13
local BOOLLIT_VAL = 14
local INPUT_CALL = 15
local SIMPLE_VAR = 16
local ARRAY_VAR = 17


-- Utility Functions

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


-- Parsing Functions

-- Each of the following is a parsing function for a nonterminal in the
-- grammar. Each function parses the nonterminal in its name and returns
-- a pair: boolean, AST. On a successul parse, the boolean is true, the
-- AST is valid, and the current lexeme is just past the end of the
-- string the nonterminal expanded into. Otherwise, the boolean is
-- false, the AST is not valid, and no guarantees are made about the
-- current lexeme. See the AST Specification near the beginning of this
-- file for the format of the returned AST.

-- NOTE. Declare parsing functions "local" above, but not below. This
-- allows them to be called before their definitions.


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
    local good, ast1, ast2, ast3, savelex, arrayflag

    savelex = lexstr

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

    elseif matchString("func") then
        savelex = lexstr
        if not matchCat(lexit.ID) then
            return false, nil
        end

        if not matchString("(") then
            return false, nil
        end

        ast3 = {FUNC_DEF , savelex}

        if matchString(")") then
            ast2 = {STMT_LIST}
            while not matchString("end") do
                good, ast1 = parse_statement()
                if not good then
                    return false, nil
                end
                if lextcat == 0 then
                    return false, nil
                end
                table.insert(ast2,ast1)
            end
            table.insert(ast3, ast2)
            return true, ast3
        end

        return false, nil

    elseif matchString("while") then
        savelex = lexstr

        ast3 = {WHILE_STMT}

        good, ast1 = parse_func_id()
        if not good then 
            return false
        end

        table.insert(ast3,ast1)

        ast2 = {STMT_LIST}

        while not matchString("end") do
            good, ast1 = parse_statement()
            if not good then
                return false, nil
            end
            if lextcat == 0 then
                return false, nil
            end
            table.insert(ast2,ast1)
        end
        table.insert(ast3,ast2)
        return true, ast3

    elseif matchString("if") then
        local newStmt, endofif
        ast3 = {IF_STMT}

        good, ast1 = parse_func_id()
        if not good then 
            return false
        end

        table.insert(ast3,ast1)

        ast2 = {STMT_LIST}

        while not matchString("end") do
            good, ast1, newStmt = parse_if_stmt()
            if not good then 
                return false
            end
            if newStmt == 1 or newStmt == 2 then
                if endofif == 1 then
                    return false, nil
                end
                table.insert(ast3,ast2)
                table.insert(ast3,ast1)
                ast2 = {STMT_LIST}
                if newStmt == 2 then
                    endofif = 1
                end
            else
                table.insert(ast2,ast1)
            end
            
        end
        table.insert(ast3,ast2)
        return true, ast3

    elseif matchCat(lexit.ID) then
        
        if matchString("(") then
            if matchString(")") then
                return true, {FUNC_CALL, savelex}
            end
            return false, nil
        end

        ast3 = {ASSN_STMT}
        ast1 =  { SIMPLE_VAR, savelex }

        if matchString("[") then
            ast1 = { ARRAY_VAR, savelex }
            savelex = lexstr
            if not matchCat(lexit.NUMLIT) then
                return false, nil
            end
            ast2 = { NUMLIT_VAL, savelex}
            if matchString("]") then
                table.insert(ast1, ast2)
            else
                return false, nil
            end
            
        end
        
        if not matchString("=") or lexstr == "end" then
            return false, nil
        end

        if lexcat == 0 then
            return false, nil
        end

        savelex = lexstr
        good, ast2 = parse_func_id()
        if not good then
            return false, nil
        end

        table.insert(ast3, ast1)
        
        if matchString("(") then
            if matchString(")") then
                ast2 = {FUNC_CALL, savelex}
            else
                return false, nil
            end
        end
        
        table.insert(ast3,ast2)
        return true, ast3

    end

end

function parse_print_arg()
    local savelex, good, ast

    savelex = lexstr
    if matchCat(lexit.STRLIT) then
        return true, { STRLIT_OUT, savelex }
    end

    return false, nil

end

function check_op(typeVar,savelex)
    local good, ast1, ast2
    local  ast3 = {}
    ast2 = {typeVar, savelex}
    ast3[1] = {BIN_OP, lexstr}
    if matchCat(lexit.OP) or matchString("and") or matchString("or") then
        savelex = lexstr
        good, ast1 = parse_func_id()
        if not good then
            return false, nil
        end
        table.insert(ast3, ast2)
        table.insert(ast3, ast1)
        return true, ast3
    end
    return true, ast2
end

function parse_func_id()
    local good, ast1, ast2, savelex
    savelex = lexstr

    if matchString("true") or matchString("false") then
        return true, {BOOLLIT_VAL, savelex}
    elseif matchCat(lexit.NUMLIT) then
        good, ast1 = check_op(NUMLIT_VAL,savelex)
        if not good then
            return false, nil
        end
        return true, ast1
    elseif matchCat(lexit.ID) then
        good, ast1 = check_op(SIMPLE_VAR,savelex)
        if not good then
            return false, nil
        end
        return true, ast1
    else
        return false, nil
    end  
end

function parse_if_stmt()
    local good, ast1, ast2, ast3, savelex
    savelex = lexstr

    if matchString("else") then
        return true, nil, 2
    elseif matchString("elif") then
        good, ast1 = parse_func_id()
        if not good then
            return false, nil
        end
        return true, ast1, 1

    end

    good, ast1 = parse_statement()
    if not good then
        return false, nil
    end
    if lextcat == 0 then
        return false, nil
    end

    return true, ast1, 0
end


-- Module Export

return parseit

