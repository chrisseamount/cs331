parseit = require "parseit"

local STMTxLIST    = 1
local PRINTxSTMT   = 2
local FUNCxDEF     = 3
local FUNCxCALL    = 4
local IFxSTMT      = 5
local WHILExSTMT   = 6
local RETURNxSTMT  = 7
local ASSNxSTMT    = 8
local STRLITxOUT   = 9
local CHARxCALL    = 10
local BINxOP       = 11
local UNxOP        = 12
local NUMLITxVAL   = 13
local BOOLLITxVAL  = 14
local INPUTxCALL   = 15
local SIMPLExVAR   = 16
local ARRAYxVAR    = 17


-- String forms of symbolic constants

symbolNames = {
  [1]="STMT_LIST",
  [2]="PRINT_STMT",
  [3]="FUNC_DEF",
  [4]="FUNC_CALL",
  [5]="IF_STMT",
  [6]="WHILE_STMT",
  [7]="RETURN_STMT",
  [8]="ASSN_STMT",
  [9]="STRLIT_OUT",
  [10]="CHAR_CALL",
  [11]="BIN_OP",
  [12]="UN_OP",
  [13]="NUMLIT_VAL",
  [14]="BOOLLIT_VAL",
  [15]="INPUT_CALL",
  [16]="SIMPLE_VAR",
  [17]="ARRAY_VAR",
}

function printAST_parseit(...)
    if select("#", ...) ~= 1 then
        error("printAST_parseit: must pass exactly 1 argument")
    end
    local x = select(1, ...)  -- Get argument (which may be nil)

    if type(x) == "nil" then
        io.write("nil")
    elseif type(x) == "number" then
        if symbolNames[x] then
            io.write(symbolNames[x])
        else
            io.write(x)
        end
    elseif type(x) == "string" then
        io.write('"'..x..'"')
    elseif type(x) == "boolean" then
        if x then
            io.write("true")
        else
            io.write("false")
        end
    elseif type(x) ~= "table" then
        io.write('<'..type(x)..'>')
    else  -- type is "table"
        io.write("{ ")
        local first = true  -- First iteration of loop?
        local maxk = 0
        for k, v in ipairs(x) do
            if first then
                first = false
            else
                io.write(", ")
            end
            maxk = k
            printAST_parseit(v)
        end
        for k, v in pairs(x) do
            if type(k) ~= "number"
              or k ~= math.floor(k)
              or (k < 1 and k > maxk) then
                if first then
                    first = false
                else
                    io.write(", ")
                end
                io.write("[")
                printAST_parseit(k)
                io.write("]=")
                printAST_parseit(v)
            end
        end
        io.write(" }")
    end
end

testString = [[
#test program
#chris seamount
print(hh[22]+5)
func foo()
    while bar() == 5
        print("Hello")
        subbar()
    end
    return bar()
end]]

good, done, ast = parseit.parse(testString)
print("*************Test Program*************")
print(testString)
print("**************************************")
print("Good: " .. tostring(good))
print("Done: " .. tostring(done))
print("AST:")
printAST_parseit(ast)
print()