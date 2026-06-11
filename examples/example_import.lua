--[[
  LuaX Example: Import Feature
  ----------------------------
  Demonstrates the import syntax for requiring modules.
]]

-- Import with default binding
local http = require("http")
local __luax_import_1 = require("json")
local parse, stringify = (__luax_import_1.parse), (__luax_import_1.stringify)
local response = http.get("https://example.com")
local data = parse(response)

print("Status: " .. tostring(data.status))
print("Data:", stringify(data))
