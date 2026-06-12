#!/usr/bin/env luajit
--[[
  LuaX v0.3 - Main Entry Point
  =============================
  Transpiler for Extended Lua with improved error handling,
  diagnostic tools (doctor), and expanded CLI.

  Usage:
    luax compile <input.lx> [output.lua]
    luax run <input.lx> [args...]
    luax build <input.lx> [output.lua]
    luax check <input.lx>
    luax fmt <input.lx> [--in-place]
    luax doctor <input.lx>
    luax help

  Killer Feature: luax doctor - Full diagnostic analysis
]]

-- Setup package path for src/ modules
package.path = package.path .. ";./?.lua;./src/?.lua;./src/?/init.lua"

local CLI = require("cli.cli")

-- Get command line arguments (skip script name)
local args = {}
for i = 1, #arg do
  table.insert(args, arg[i])
end

-- Dispatch to CLI
CLI.main(args)
