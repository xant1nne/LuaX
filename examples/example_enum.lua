--[[
  LuaX Example: Enum Feature
  ---------------------------
  Demonstrates the enum syntax for creating enumerated types.
]]

-- Define an enum
local Direction = {
    North = 1,
    South = 2,
    East = 3,
    West = 4,
}
local HttpStatus = {
    Ok = 200,
    NotFound = 404,
    ServerError = 500,
}
local Color = {
    Red = 1,
    Green = 10,
    Blue = 11,
    Yellow = 20,
    Purple = 21,
}
local currentDirection = Direction.North
local statusCode = HttpStatus.Ok

print("Direction: " .. currentDirection)
print("Status: " .. statusCode)

-- Iterate over enum values
for name, value in pairs(Direction) do
    print(name .. " = " .. tostring(value))
end
