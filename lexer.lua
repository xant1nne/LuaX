--[[
  LuaX Lexer
  Uses string.* (not str:method) so it works in mlua without string metatable.
]]

local Errors = require("errors")

local Lexer = {}
local S = string

local DEBUG = os.getenv and os.getenv("LUAX_LEXER_DEBUG") == "1"

local function debug_type(label, value)
  if not DEBUG then return end
  io.stderr:write(string.format(
    "[lexer debug] %s: type=%s value=%s\n",
    label, type(value), tostring(value)
  ))
end

local function expect_string(name, value)
  if type(value) ~= "string" then
    debug_type(name, value)
    if type(value) == "table" then
      error(name .. ": expected string source, got table (did you pass tokens to Parser.parse?)")
    end
    error(name .. ": expected string, got " .. type(value))
  end
end

local KEYWORDS = {
  ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
  ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
  ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
  ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
  ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
  ["while"] = true,
}

local MULTI_SYMBOLS = {
  "...", "..", "::", "==", "~=", "<=", ">=",
}

local function is_digit(c) return c and S.match(c, "%d") ~= nil end
local function is_alpha(c) return c and S.match(c, "[%a_]") ~= nil end
local function is_alnum(c) return c and S.match(c, "[%w_]") ~= nil end

local function read_long_bracket(src, pos, ctx, startLine)
  local i = pos
  if S.sub(src, i, i) ~= "[" then return nil end
  local j = i + 1
  local level = 0
  while S.sub(src, j, j) == "=" do
    level = level + 1
    j = j + 1
  end
  if S.sub(src, j, j) ~= "[" then return nil end
  local contentStart = j + 1
  if S.sub(src, contentStart, contentStart) == "\r" and S.sub(src, contentStart + 1, contentStart + 1) == "\n" then
    contentStart = contentStart + 2
  elseif S.sub(src, contentStart, contentStart) == "\n" or S.sub(src, contentStart, contentStart) == "\r" then
    contentStart = contentStart + 1
  end

  local closePattern = "%]" .. S.rep("=", level) .. "%]"
  local closeStart, closeEnd = S.find(src, closePattern, contentStart)
  if not closeStart then
    Errors.raise(ctx, startLine, pos, "unfinished long bracket")
  end
  local content = S.sub(src, contentStart, closeStart - 1)
  local raw = S.sub(src, pos, closeEnd)
  return content, raw, closeEnd + 1
end

function Lexer.tokenize(source, ctx)
  expect_string("Lexer.tokenize(source)", source)
  ctx = ctx or Errors.context(nil, source)
  local tokens = {}
  local pos = 1
  local line = 1
  local n = #source

  local function advance_line_count(text)
    expect_string("Lexer.tokenize(text)", text)
    local _, count = S.gsub(text, "\n", "\n")
    line = line + count
  end

  while pos <= n do
    local c = S.sub(source, pos, pos)

    if S.match(c, "%s") then
      if c == "\n" then line = line + 1 end
      pos = pos + 1

    elseif c == "-" and S.sub(source, pos + 1, pos + 1) == "-" then
      local afterDashes = pos + 2
      local content, raw, nextPos = read_long_bracket(source, afterDashes, ctx, line)
      if content then
        advance_line_count(raw)
        pos = nextPos
      else
        local nlPos = S.find(source, "\n", afterDashes, true)
        if nlPos then
          pos = nlPos
        else
          pos = n + 1
        end
      end

    elseif c == "[" and (S.sub(source, pos + 1, pos + 1) == "[" or S.sub(source, pos + 1, pos + 1) == "=") then
      local content, raw, nextPos = read_long_bracket(source, pos, ctx, line)
      if content then
        table.insert(tokens, {
          type = "String", value = content, raw = raw,
          line = line, startPos = pos, endPos = nextPos,
        })
        advance_line_count(raw)
        pos = nextPos
      else
        table.insert(tokens, {
          type = "Symbol", value = "[", raw = "[",
          line = line, startPos = pos, endPos = pos + 1,
        })
        pos = pos + 1
      end

    elseif c == '"' or c == "'" then
      local quote = c
      local startPos = pos
      local startLine = line
      local j = pos + 1
      local buf = {}
      while true do
        local ch = S.sub(source, j, j)
        if ch == "" then
          Errors.raise(ctx, startLine, startPos, "unfinished string")
        elseif ch == quote then
          j = j + 1
          break
        elseif ch == "\\" then
          local nextCh = S.sub(source, j + 1, j + 1)
          table.insert(buf, ch)
          table.insert(buf, nextCh)
          if nextCh == "\n" then line = line + 1 end
          j = j + 2
        elseif ch == "\n" then
          Errors.raise(ctx, startLine, startPos, "unfinished string")
        else
          table.insert(buf, ch)
          j = j + 1
        end
      end
      local raw = S.sub(source, startPos, j - 1)
      table.insert(tokens, {
        type = "String", value = table.concat(buf), raw = raw,
        line = startLine, startPos = startPos, endPos = j,
      })
      pos = j

    elseif is_digit(c) or (c == "." and is_digit(S.sub(source, pos + 1, pos + 1))) then
      local startPos = pos
      local j = pos
      if c == "0" and (S.sub(source, j + 1, j + 1) == "x" or S.sub(source, j + 1, j + 1) == "X") then
        j = j + 2
        while S.match(S.sub(source, j, j), "[%x]") do j = j + 1 end
      else
        while is_digit(S.sub(source, j, j)) do j = j + 1 end
        if S.sub(source, j, j) == "." then
          j = j + 1
          while is_digit(S.sub(source, j, j)) do j = j + 1 end
        end
        local expChar = S.sub(source, j, j)
        if expChar == "e" or expChar == "E" then
          local k = j + 1
          if S.sub(source, k, k) == "+" or S.sub(source, k, k) == "-" then k = k + 1 end
          if is_digit(S.sub(source, k, k)) then
            j = k
            while is_digit(S.sub(source, j, j)) do j = j + 1 end
          end
        end
      end
      local raw = S.sub(source, startPos, j - 1)
      table.insert(tokens, {
        type = "Number", value = raw, raw = raw,
        line = line, startPos = startPos, endPos = j,
      })
      pos = j

    elseif is_alpha(c) then
      local startPos = pos
      local j = pos + 1
      while is_alnum(S.sub(source, j, j)) do j = j + 1 end
      local raw = S.sub(source, startPos, j - 1)
      local ttype = KEYWORDS[raw] and "Keyword" or "Name"
      table.insert(tokens, {
        type = ttype, value = raw, raw = raw,
        line = line, startPos = startPos, endPos = j,
      })
      pos = j

    else
      local matched
      for _, sym in ipairs(MULTI_SYMBOLS) do
        if S.sub(source, pos, pos + #sym - 1) == sym then
          matched = sym
          break
        end
      end
      if matched then
        table.insert(tokens, {
          type = "Symbol", value = matched, raw = matched,
          line = line, startPos = pos, endPos = pos + #matched,
        })
        pos = pos + #matched
      else
        table.insert(tokens, {
          type = "Symbol", value = c, raw = c,
          line = line, startPos = pos, endPos = pos + 1,
        })
        pos = pos + 1
      end
    end
  end

  table.insert(tokens, {
    type = "EOF", value = "", raw = "",
    line = line, startPos = n + 1, endPos = n + 1,
  })

  return tokens
end

return Lexer
