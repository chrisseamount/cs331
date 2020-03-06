-- lexit.lua
-- Christopher Seamount
-- Started: 2020-02-17
--
-- For CS F331 Spring 2020
-- hw#3 Lexer for the Degu language

-- *********************************************************************
-- Module Table Initialization
-- *********************************************************************


local lexit = {}  -- Our module; members are added below


-- *********************************************************************
-- Public Constants
-- *********************************************************************


-- Numeric constants representing lexeme categories
lexit.KEY    = 1
lexit.ID     = 2
lexit.NUMLIT = 3
lexit.STRLIT = 4
lexit.OP     = 5
lexit.PUNCT  = 6
lexit.MAL    = 7


-- catnames
-- Array of names of lexeme categories.
-- Human-readable strings. Indices are above numeric constants.
lexit.catnames = {
    "Keyword",
    "Identifier",
    "NumericLiteral",
    "StringLiteral",
    "Operator",
    "Punctuation",
    "Malformed"
}

-- keywords
-- Array of the 15 accepted keywords in Degu. Used in
-- handle_LETTER.
local keywords = {
    "and",
    "char",
    "elif",
    "else",
    "end",
    "false",
    "func",
    "if",
    "input",
    "not",
    "or",
    "print",
    "return",
    "true",
    "while"
}

-- operators
-- Array of accepted single character operators. Used in
-- handle_OPERATOR. '!' is a punctuation but '!=' is an 
-- operator. handle_OPERATOR handles this.
local operators = {
    "=",
    "!",
    "<",
    ">",
    "+",
    "-",
    "*",
    "/",
    "%",
    "[",
    "]",
    "="
}

-- type
-- Variable used to hold quote type for String Literals.
local type = ""


-- *********************************************************************
-- Kind-of-Character Functions
-- *********************************************************************

-- All functions return false when given a string whose length is not
-- exactly 1.


-- isLetter
-- Returns true if string c is a letter character, false otherwise.
local function isLetter(c)
    if c:len() ~= 1 then
        return false
    elseif c >= "A" and c <= "Z" then
        return true
    elseif c >= "a" and c <= "z" then
        return true
    else
        return false
    end
end


-- isDigit
-- Returns true if string c is a digit character, false otherwise.
local function isDigit(c)
    if c:len() ~= 1 then
        return false
    elseif c >= "0" and c <= "9" then
        return true
    else
        return false
    end
end


-- isWhitespace
-- Returns true if string c is a whitespace character, false otherwise.
local function isWhitespace(c)
    if c:len() ~= 1 then
        return false
    elseif c == " " or c == "\t" or c == "\n" or c == "\r"
      or c == "\f" then
        return true
    else
        return false
    end
end


-- isPrintableASCII
-- Returns true if string c is a printable ASCII character (codes 32 " "
-- through 126 "~"), false otherwise.
local function isPrintableASCII(c)
    if c:len() ~= 1 then
        return false
    elseif c >= " " and c <= "~" then
        return true
    else
        return false
    end
end


-- isIllegal
-- Returns true if string c is an illegal character, false otherwise.
local function isIllegal(c)
    if c:len() ~= 1 then
        return false
    elseif isWhitespace(c) then
        return false
    elseif isPrintableASCII(c) then
        return false
    else
        return true
    end
end


-- *********************************************************************
-- The Lexer
-- *********************************************************************


-- lex
-- Our lexer
-- Intended for use in a for-in loop:
--     for lexstr, cat in lexit.lex(program) do
-- Here, lexstr is the string form of a lexeme, and cat is a number
-- representing a lexeme category. (See Public Constants.)
function lexit.lex(program)
    -- ***** Variables (like class data members) *****

    local pos       -- Index of next character in program
                    -- INVARIANT: when getLexeme is called, pos is
                    --  EITHER the index of the first character of the
                    --  next lexeme OR program:len()+1
    local state     -- Current state for our state machine
    local ch        -- Current character
    local lexstr    -- The lexeme, so far
    local category  -- Category of lexeme, set when state set to DONE
    local handlers  -- Dispatch table; value created later

    -- ***** States *****

    local DONE      = 0
    local START     = 1
    local LETTER    = 2
    local DIGIT     = 3
    local OPERATOR  = 4
    local EXPONENT  = 5
    local STRING    = 6

    -- ***** Character-Related Utility Functions *****

    -- currChar
    -- Return the current character, at index pos in program. Return
    -- value is a single-character string, or the empty string if pos is
    -- past the end.
    local function currChar()
        return program:sub(pos, pos)
    end

    -- nextChar
    -- Return the next character, at index pos+1 in program. Return
    -- value is a single-character string, or the empty string if pos+1
    -- is past the end.
    local function nextChar()
        return program:sub(pos+1, pos+1)
    end

    -- nextnextChar
    -- Returns the character at index pos+2 in program. Return value
    -- is a single-character string, or the empty string if pos+2 is
    -- past the end.
    local function nextnextChar()
        return program:sub(pos+2, pos+2)
    end

    -- drop1
    -- Move pos to the next character.
    local function drop1()
        pos = pos+1
    end

    -- add1
    -- Add the current character to the lexeme, moving pos to the next
    -- character.
    local function add1()
        lexstr = lexstr .. currChar()
        drop1()
    end

    -- skipWhitespace
    -- Skip whitespace and comments, moving pos to the beginning of
    -- the next lexeme, or to program:len()+1.
    local function skipWhitespace()
        while true do      -- In whitespace
            while isWhitespace(currChar()) do
                drop1()
            end

            if currChar() ~= "#" then  -- Comment?
                break
            end
            drop1()

            while true do  -- In comment
                if currChar() == "" or currChar() == "\n" then  -- End of input?
                    drop1()
                    return
                end
                drop1()
            end
        end
    end

    -- hasValue
    -- Given table tab and value val and determines if the value
    -- is in the table.
    local function hasValue(tab, val)
        for k, v in ipairs(tab) do
            if v == val then
                return true
            end
        end

        return false
    end

    -- ***** State-Handler Functions *****

    -- A function with a name like handle_XYZ is the handler function
    -- for state XYZ

    local function handle_DONE()
        error("'DONE' state should not be handled\n")
    end

    local function handle_START()
        if isIllegal(ch) then
            add1()
            state = DONE
            category = lexit.MAL
        elseif isLetter(ch) or ch == "_" then
            add1()
            state = LETTER
        elseif isDigit(ch) then
            add1()
            state = DIGIT
        elseif ch == "\"" or ch == "'" then
            type = ch
            add1()
            state = STRING
        elseif ch == "." then
            add1()
            state = DONE
            category = lexit.PUNCT
        elseif hasValue(operators, ch) then
            state = OPERATOR
        else
            add1()
            state = DONE
            category = lexit.PUNCT
        end
    end

    local function handle_LETTER()
        if isLetter(ch) or isDigit(ch) or ch == "_" then
            add1()
        else
            state = DONE
            if hasValue(keywords, lexstr) then
                category = lexit.KEY
            else
                category = lexit.ID
            end
        end
    end

    local function handle_DIGIT()
        if isDigit(ch) then
            add1()
            return
        elseif ch == "e" or ch == "E" then
            if isDigit(nextChar()) then
                add1()
                add1()
                state = EXPONENT
                return
            elseif nextChar() == "+" then
                if isDigit(nextnextChar()) then
                    add1()
                    add1()
                    add1()
                    state = EXPONENT
                    return
                end
            end
        end
        state = DONE
        category = lexit.NUMLIT
    end

    local function handle_OPERATOR()
        if ch == "!" and nextChar() ~= "=" then
            add1()
            state = DONE
            category = lexit.PUNCT
        elseif (ch == "=" or ch == "!" or ch == "<" or ch == ">")
        and nextChar() == "=" then
            add1()
            add1()
            state = DONE
            category = lexit.OP
        else
            add1()
            state = DONE
            category = lexit.OP
        end
    end

    local function handle_EXPONENT()
        if isDigit(ch) then
            add1()
        else
            state = DONE
            category = lexit.NUMLIT
        end
        
    end

    local function handle_STRING()
        if ch == type then
            add1()
            state = DONE
            category = lexit.STRLIT
        elseif ch == "\\" and nextChar() == "\\" then
            add1()
            add1()
        elseif ch == "\\" and nextChar() == type then
            add1()
            add1()
        elseif ch == "" then
            state = DONE
            category = lexit.MAL
        else
            add1()
        end

    end

    -- ***** Table of State-Handler Functions *****

    handlers = {
        [DONE]=handle_DONE,
        [START]=handle_START,
        [LETTER]=handle_LETTER,
        [DIGIT]=handle_DIGIT,
        [OPERATOR]=handle_OPERATOR,
        [EXPONENT]=handle_EXPONENT,
        [STRING]=handle_STRING,
    }

    -- ***** Iterator Function *****

    -- getLexeme
    -- Called each time through the for-in loop.
    -- Returns a pair: lexeme-string (string) and category (int), or
    -- nil, nil if no more lexemes.
    local function getLexeme(dummy1, dummy2)
        if pos > program:len() then
            return nil, nil
        end
        lexstr = ""
        state = START
        skipWhitespace()
        while state ~= DONE do
            ch = currChar()
            if state ~= STRING then
                skipWhitespace()
            end
            handlers[state]()
        end

        skipWhitespace()
        return lexstr, category
    end

    -- ***** Body of Function lex *****

    -- Initialize & return the iterator function
    pos = 1
    skipWhitespace()
    return getLexeme, nil, nil
end


-- *********************************************************************
-- Module Table Return
-- *********************************************************************


return lexit

