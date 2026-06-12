--[[
  LuaX Code Generator (v0.2)
  Concatenates RawLua chunks with clean spacing.
]]

local AST = require("ast")
local S = string

local Codegen = {}

local function trim_trailing_ws(code)
  return (S.gsub(code, "[%s\r\n]+$", ""))
end

function Codegen.generate(ast)
  AST.validate(ast, "codegen")
  local chunks = {}

  for _, node in ipairs(ast.body) do
    if node.type == "RawLua" then
      local code = trim_trailing_ws(node.code)
      if code ~= "" then
        table.insert(chunks, code)
      end
    elseif node.type == "Import" then
      error("codegen: unprocessed Import node")
    elseif node.type == "Enum" then
      error("codegen: unprocessed Enum node")
    elseif node.type == "TypeAlias" then
      error("codegen: unprocessed TypeAlias node")
    elseif node.type == "Class" then
      error("codegen: unprocessed Class node (class_transform failed?)")
    elseif node.type == "AsyncFunc" then
      error("codegen: unprocessed AsyncFunc node (async_transform failed?)")
    end
  end

  if #chunks == 0 then
    return ""
  end
  return table.concat(chunks, "\n") .. "\n"
end

return Codegen
