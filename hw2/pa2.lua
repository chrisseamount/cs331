-- pa2.lua
-- Christopher Seamount
-- 2020-02-11
--
-- For CS331 Spring 2020
-- Functions for Assignment 2
-- Used in Assignment 2, Exercise 2

-- pa2
-- Container for all functions required for Assignment 2
local pa2 = {}

-- filterTable
-- Given function p, returns returns all key value pairs for which
-- values are truthy when passed to function p.
-- p must be a function and t must be a table of values. All values
-- in t must be compatable with function p.
function pa2.filterTable(p,t)
  local temp = {}
  for k,v in pairs(t) do
    if p(v) then
      temp[k] = v
    end
  end
  return temp
end

-- concatMax
-- Given string str and integer int, returns a string which is the concatination of as
-- many copies of string str as possible while not exeeding int number of characters. Returns
-- the empty string if the length of str is larger than the value of int.
-- str must be a string and int must be a positive integer.
function pa2.concatMax(str,int)
  local temp = ""
  for i=string.len(str),int,string.len(str) do
    temp = temp .. str
  end
  return temp
end

-- collatz
-- Coroutine is given an integer value k and yeilds all values of the collatz sequence
-- starting from k.
-- k must be a positive integer.
function pa2.collatz(k)
  while k>1 do
    coroutine.yield(k)
    if k%2 == 0 then
      k = k/2
    else
      k = 3*k+1
    end
  end
  coroutine.yield(1)
end

-- allSubs
-- Given string s, returns all substrings of sizes ranging from the empty string
-- to the length of the given string.
-- s must be a string. An empty string is an acceptable input.
-- Ex: "acbd" would return iterators for "","a","c","b","d","ac","cb","bd","acb","cbd","acbd"
function pa2.allSubs(s)
  local i, k, n = 0, 0, string.len(s)
  local temp = ""
  local function iter()
    temp = string.sub(s,i,k)
    if k == n then -- when k reaches end of string calculate new offset of i and k
      k = n - i + 2
      i = 1
      return temp
    elseif k < n then -- walk trough string
      i = i + 1
      k = k + 1
      return temp
    end
  end
  return iter
end

return pa2
