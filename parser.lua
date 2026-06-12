--[[
  LuaX Parser
  Single-pass parser: LuaX declarations at top level, everything else as RawLua.
]]

local Lexer = require("lexer")
local AST = require("ast")
local Errors = require("errors")
local S = string

local Parser = {}

local BLOCK_OPENERS = {
  ["function"] = true, ["if"] = true, ["for"] = true,
  ["while"] = true, ["do"] = true,
}

local function parse_import(tokens, i, ctx)
  local startTok = tokens[i]
  local j = i + 1
  local node = { line = startTok.line }

  local nameTok = tokens[j]
  if nameTok.type == "Name" then
    node.kind = "default"
    node.name = nameTok.value
    j = j + 1
  elseif nameTok.type == "Symbol" and nameTok.value == "{" then
    node.kind = "named"
    node.names = {}
    j = j + 1
    while true do
      local t = tokens[j]
      if t.type == "Symbol" and t.value == "}" then
        j = j + 1
        break
      elseif t.type == "Name" then
        table.insert(node.names, t.value)
        j = j + 1
        local sep = tokens[j]
        if sep.type == "Symbol" and sep.value == "," then
          j = j + 1
        end
      else
        Errors.expected(ctx, t, "identifier or '}'")
      end
    end
  else
    Errors.expected(ctx, nameTok, "identifier or '{'")
  end

  local fromTok = tokens[j]
  if not (fromTok.type == "Name" and fromTok.value == "from") then
    Errors.expected(ctx, fromTok, "'from'")
  end
  j = j + 1

  local moduleTok = tokens[j]
  if moduleTok.type ~= "String" then
    Errors.expected(ctx, moduleTok, "module string")
  end
  node.module = moduleTok.value
  j = j + 1

  if tokens[j].type == "Symbol" and tokens[j].value == ";" then
    j = j + 1
  end

  return AST.Import(node), j
end

local function parse_enum_body(tokens, i, ctx)
  local members = {}
  local j = i + 1

  while true do
    local t = tokens[j]
    if t.type == "Symbol" and t.value == "}" then
      j = j + 1
      break
    elseif t.type == "EOF" then
      Errors.raise_token(ctx, t, "unexpected end of file inside enum body")
    elseif t.type == "Name" or t.type == "Keyword" then
      local member = { name = t.value }
      j = j + 1
      local nextTok = tokens[j]
      if nextTok.type == "Symbol" and nextTok.value == "=" then
        j = j + 1
        local valTok = tokens[j]
        local sign = 1
        if valTok.type == "Symbol" and valTok.value == "-" then
          sign = -1
          j = j + 1
          valTok = tokens[j]
        end
        if valTok.type ~= "Number" then
          Errors.expected(ctx, valTok, "numeric literal")
        end
        member.value = sign * tonumber(valTok.value)
        j = j + 1
      end
      table.insert(members, member)
      local sep = tokens[j]
      if sep.type == "Symbol" and sep.value == "," then
        j = j + 1
      end
    else
      Errors.raise_token(ctx, t, "unexpected token in enum body")
    end
  end

  return members, j
end

local function parse_enum(tokens, i, ctx)
  local startTok = tokens[i]
  local j = i + 1

  local nameTok = tokens[j]
  if nameTok.type ~= "Name" then
    Errors.expected(ctx, nameTok, "enum name")
  end
  local name = nameTok.value
  j = j + 1

  local braceTok = tokens[j]
  if not (braceTok.type == "Symbol" and braceTok.value == "{") then
    Errors.expected(ctx, braceTok, "'{'")
  end

  local members, nextJ = parse_enum_body(tokens, j, ctx)
  return AST.Enum({ line = startTok.line, name = name, members = members }), nextJ
end

local function skip_balanced(tokens, i, ctx)
  local openers = { ["("] = ")", ["["] = "]", ["{"] = "}" }
  local open = tokens[i].value
  local close = openers[open]
  if not close then
    Errors.raise_token(ctx, tokens[i], "internal error: unbalanced group")
  end
  local depth = 0
  local j = i
  while true do
    local t = tokens[j]
    if t.type == "EOF" then
      Errors.raise_token(ctx, t, "unexpected end of file (unbalanced '" .. open .. "')")
    elseif t.type == "Symbol" and t.value == open then
      depth = depth + 1
    elseif t.type == "Symbol" and t.value == close then
      depth = depth - 1
      if depth == 0 then
        return j + 1
      end
    end
    j = j + 1
  end
end

local function parse_type_alias(tokens, i, source, ctx)
  local startTok = tokens[i]
  local nameTok = tokens[i + 1]
  local name = nameTok.value
  local eqIdx = i + 2

  local j = eqIdx + 1
  local valueTok = tokens[j]
  local endIdx

  if valueTok.type == "Symbol" and (valueTok.value == "{" or valueTok.value == "(" or valueTok.value == "[") then
    endIdx = skip_balanced(tokens, j, ctx) - 1
  else
    local declLine = startTok.line
    endIdx = j
    while true do
      local nextTok = tokens[endIdx + 1]
      if nextTok.type == "EOF" then break end
      if nextTok.line ~= tokens[endIdx].line then break end
      endIdx = endIdx + 1
    end
  end

  local nextJ = endIdx + 1
  if tokens[nextJ].type == "Symbol" and tokens[nextJ].value == ";" then
    nextJ = nextJ + 1
  end

  local raw = S.sub(source, startTok.startPos, tokens[endIdx].endPos - 1)
  return AST.TypeAlias({ line = startTok.line, name = name, raw = raw }), nextJ
end

function Parser.parse(source, opts)
  opts = opts or {}
  local ctx = Errors.context(opts.file, source)
  local tokens = Lexer.tokenize(source, ctx)
  local body = {}

  local depth = 0
  local bracketDepth = 0
  local expectingDo = false
  local rawStart = 1

  local function flush_raw(uptoBytePos)
    if uptoBytePos > rawStart then
      table.insert(body, AST.RawLua(S.sub(source, rawStart, uptoBytePos - 1)))
    end
  end

  local function update_depth(tok)
    if tok.type == "Keyword" then
      local v = tok.value
      if v == "function" or v == "if" then
        depth = depth + 1
      elseif v == "for" or v == "while" then
        depth = depth + 1
        expectingDo = true
      elseif v == "repeat" then
        depth = depth + 1
      elseif v == "do" then
        if expectingDo then
          expectingDo = false
        else
          depth = depth + 1
        end
      elseif v == "end" then
        if depth > 0 then depth = depth - 1 end
      elseif v == "until" then
        if depth > 0 then depth = depth - 1 end
      end
    elseif tok.type == "Symbol" then
      local v = tok.value
      if v == "(" or v == "[" or v == "{" then
        bracketDepth = bracketDepth + 1
      elseif v == ")" or v == "]" or v == "}" then
        if bracketDepth > 0 then bracketDepth = bracketDepth - 1 end
      end
    end
  end

  local function is_decl_start(i)
    if i <= 1 then return true end
    local prev = tokens[i - 1]
    return not (prev.type == "Keyword" and prev.value == "local")
  end

  local i = 1
  local n = #tokens
  while i <= n do
    local tok = tokens[i]
    if tok.type == "EOF" then break end

    local atTopLevel = (depth == 0 and bracketDepth == 0)
    local declStart = atTopLevel and is_decl_start(i)

    if declStart and tok.type == "Name" and tok.value == "import" then
      flush_raw(tok.startPos)
      local node, nextI = parse_import(tokens, i, ctx)
      table.insert(body, node)
      i = nextI
      rawStart = tokens[i].startPos

    elseif declStart and tok.type == "Name" and tok.value == "enum" then
      flush_raw(tok.startPos)
      local node, nextI = parse_enum(tokens, i, ctx)
      table.insert(body, node)
      i = nextI
      rawStart = tokens[i].startPos

    elseif declStart and tok.type == "Name" and tok.value == "type"
           and tokens[i + 1] and tokens[i + 1].type == "Name"
           and tokens[i + 2] and tokens[i + 2].type == "Symbol" and tokens[i + 2].value == "=" then
      flush_raw(tok.startPos)
      local node, nextI = parse_type_alias(tokens, i, source, ctx)
      table.insert(body, node)
      i = nextI
      rawStart = tokens[i].startPos

    else
      update_depth(tok)
      i = i + 1
    end
  end

  flush_raw(#source + 1)

  local chunk = AST.Chunk(body)
  AST.validate(chunk, "parse")
  return chunk
end

return Parser
