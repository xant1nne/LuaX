--[[
  LuaX AST (v0.2)
  Fixed node types — only these five kinds are allowed.
]]

local AST = {}

AST.VERSION = "0.3"

AST.NODE_TYPES = {
  Chunk = true,
  RawLua = true,
  Import = true,
  Enum = true,
  TypeAlias = true,
  Class = true,
  AsyncFunc = true,
}

local function assert_type(node, where)
  if type(node) ~= "table" or not AST.NODE_TYPES[node.type] then
    error((where or "AST") .. ": invalid node type '" .. tostring(node and node.type) .. "'")
  end
end

function AST.validate(node, where)
  assert_type(node, where)
  if node.type == "Chunk" then
    if type(node.body) ~= "table" then error(where .. ": Chunk.body must be a table") end
    for i, child in ipairs(node.body) do
      AST.validate(child, where .. ".body[" .. i .. "]")
    end
  elseif node.type == "RawLua" then
    if type(node.code) ~= "string" then error(where .. ": RawLua.code must be a string") end
  elseif node.type == "Import" then
    if node.kind ~= "default" and node.kind ~= "named" then
      error(where .. ": Import.kind must be 'default' or 'named'")
    end
    if type(node.module) ~= "string" then error(where .. ": Import.module must be a string") end
    if node.kind == "default" and type(node.name) ~= "string" then
      error(where .. ": Import.name must be a string")
    end
    if node.kind == "named" and type(node.names) ~= "table" then
      error(where .. ": Import.names must be a table")
    end
  elseif node.type == "Enum" then
    if type(node.name) ~= "string" then error(where .. ": Enum.name must be a string") end
    if type(node.members) ~= "table" then error(where .. ": Enum.members must be a table") end
  elseif node.type == "TypeAlias" then
    if type(node.name) ~= "string" then error(where .. ": TypeAlias.name must be a string") end
    if type(node.raw) ~= "string" then error(where .. ": TypeAlias.raw must be a string") end
  elseif node.type == "Class" then
    if type(node.name) ~= "string" then error(where .. ": Class.name must be a string") end
    if type(node.methods) ~= "table" then error(where .. ": Class.methods must be a table") end
  elseif node.type == "AsyncFunc" then
    if type(node.name) ~= "string" then error(where .. ": AsyncFunc.name must be a string") end
    if type(node.body) ~= "string" then error(where .. ": AsyncFunc.body must be a string") end
  end
  return true
end

function AST.Chunk(body)
  return { type = "Chunk", body = body or {} }
end

function AST.RawLua(code)
  return { type = "RawLua", code = code }
end

function AST.Import(opts)
  return {
    type = "Import",
    line = opts.line,
    module = opts.module,
    kind = opts.kind,
    name = opts.name,
    names = opts.names,
  }
end

function AST.Enum(opts)
  return {
    type = "Enum",
    line = opts.line,
    name = opts.name,
    members = opts.members,
  }
end

function AST.Class(opts)
  return {
    type = "Class",
    line = opts.line,
    name = opts.name,
    methods = opts.methods,  -- { { name, params[], body }, ... }
  }
end

function AST.AsyncFunc(opts)
  return {
    type = "AsyncFunc",
    line = opts.line,
    name = opts.name,
    params = opts.params,
    body = opts.body,  -- RawLua code
  }
end

function AST.TypeAlias(opts)
  return {
    type = "TypeAlias",
    line = opts.line,
    name = opts.name,
    raw = opts.raw,
  }
end

return AST
