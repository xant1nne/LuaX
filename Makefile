# LuaX v0.2
LUA ?= lua

.PHONY: test check example clean

test:
	$(LUA) tests/test_all.lua
	$(LUA) tests/test_errors.lua
	$(LUA) tests/compat/lua_compat.lua

check: test

example:
	$(LUA) luax.lua build examples/example_complete.lx

clean:
	rm -f examples/*.lua *.tmp.lua *.luax.tmp.lua
