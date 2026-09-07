PLUGIN_SRC := lua
PLUGIN_DIR := tidal-ripple.nvim
TESTS_DIR := tests/plenary

.PHONY: lint format format-check test test-interactive

lint:
	luacheck $(PLUGIN_SRC) tests/

format:
	stylua $(PLUGIN_SRC) tests/

format-check:
	stylua --check $(PLUGIN_SRC) tests/

test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory $(TESTS_DIR) {minimal_init = 'tests/minimal_init.lua'}"

test-interactive:
	nvim -u tests/minimal_init.lua -c "lua require'plenary.test_harness'"
