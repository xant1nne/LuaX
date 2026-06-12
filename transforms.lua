--[[
  LuaX Transform Pipeline (v0.4)
  import -> enum -> type_strip -> class -> async
]]

local AST = require("ast")

-- Add src/transforms to path for loading new transforms
package.path = package.path .. ";./src/transforms/?.lua"

local ClassTransform = require("class_transform")
local AsyncTransform = require("async_transform")

local Transforms = {}

local function import_pass(ast)
  local out = {}
  local counter = 0

  for _, node in ipairs(ast.body) do
    if node.type == "Import" then
      if node.kind == "default" then
        table.insert(out, AST.RawLua(
          ("local %s = require(%q)"):format(node.name, node.module)
        ))
      elseif node.kind == "named" then
        counter = counter + 1
        local tmp = ("__luax_import_%d"):format(counter)
        local lines = {
          ("local %s = require(%q)"):format(tmp, node.module),
        }
        local lhs = table.concat(node.names, ", ")
        local rhsParts = {}
        for _, name in ipairs(node.names) do
          table.insert(rhsParts, ("(%s.%s)"):format(tmp, name))
        end
        table.insert(lines, ("local %s = %s"):format(lhs, table.concat(rhsParts, ", ")))
        table.insert(out, AST.RawLua(table.concat(lines, "\n")))
      else
        error("import transform: unknown kind '" .. tostring(node.kind) .. "'")
      end
    else
      table.insert(out, node)
    end
  end

  return AST.Chunk(out)
end

local function enum_pass(ast)
  local out = {}

  for _, node in ipairs(ast.body) do
    if node.type == "Enum" then
      local lines = { ("local %s = {"):format(node.name) }
      local nextValue = 1
      for _, member in ipairs(node.members) do
        local value = member.value ~= nil and member.value or nextValue
        nextValue = value + 1
        table.insert(lines, ("    %s = %d,"):format(member.name, value))
      end
      table.insert(lines, "}")
      table.insert(out, AST.RawLua(table.concat(lines, "\n")))
    else
      table.insert(out, node)
    end
  end

  return AST.Chunk(out)
end

local function type_strip_pass(ast)
  local out = {}
  for _, node in ipairs(ast.body) do
    if node.type ~= "TypeAlias" then
      table.insert(out, node)
    end
  end
  return AST.Chunk(out)
end

local function class_pass(ast)
  return ClassTransform.transform(ast)
end

local function async_pass(ast)
  return AsyncTransform.transform(ast)
end

Transforms.PASSES = { import_pass, enum_pass, type_strip_pass, class_pass, async_pass }

function Transforms.run(ast)
  AST.validate(ast, "input")
  for _, pass in ipairs(Transforms.PASSES) do
    ast = pass(ast)
    AST.validate(ast, "transform")
  end
  return ast
end

return Transforms
