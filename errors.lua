--[[
  LuaX Error Reporting (v0.2)
  Formats diagnostics as: file:line:column: error: message
]]

local Errors = {}
local S = string

function Errors.context(file, source)
  return { file = file or "<input>", source = source or "" }
end

function Errors.column(ctx, pos)
  pos = pos or 1
  local lineStart = 1
  local col = 1
  local i = 1
  while i < pos and i <= #ctx.source do
    local c = S.sub(ctx.source, i, i)
    if c == "\n" then
      lineStart = i + 1
      col = 1
    else
      col = col + 1
    end
    i = i + 1
  end
  return col
end

function Errors.format(ctx, line, pos, message)
  local col = Errors.column(ctx, pos)
  return string.format("%s:%d:%d: error: %s", ctx.file, line or 1, col, message)
end

function Errors.token_label(tok)
  if not tok then return "end of file" end
  if tok.type == "EOF" then return "end of file" end
  if tok.type == "String" then return "string literal" end
  if tok.type == "Number" then return "number" end
  if tok.type == "Keyword" then return "keyword '" .. tok.value .. "'" end
  if tok.type == "Name" then return "identifier '" .. tok.value .. "'" end
  return "'" .. (tok.raw or tok.value or "?") .. "'"
end

function Errors.raise(ctx, line, pos, message)
  error(Errors.format(ctx, line, pos, message), 0)
end

function Errors.raise_token(ctx, tok, message)
  Errors.raise(ctx, tok.line, tok.startPos, message)
end

function Errors.expected(ctx, tok, expected)
  Errors.raise_token(ctx, tok, "expected " .. expected .. ", got " .. Errors.token_label(tok))
end

return Errors
