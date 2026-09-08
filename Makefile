PLUGIN_SRC := lua
PLUGIN_DIR := tidal-ripple.nvim
TESTS_DIR := tests/plenary

# Project specs (excludes vendored losc specs, which are red on LuaJIT and slow)
CORE_SPECS := \
	$(TESTS_DIR)/completion_data_spec.lua \
	$(TESTS_DIR)/completion_parser_spec.lua \
	$(TESTS_DIR)/config_spec.lua \
	$(TESTS_DIR)/ctrl_spec.lua \
	$(TESTS_DIR)/ghci_spec.lua \
	$(TESTS_DIR)/mininotation_spec.lua \
	$(TESTS_DIR)/statusline_spec.lua \
	$(TESTS_DIR)/symbols_spec.lua \
	$(TESTS_DIR)/util_spec.lua

# Vendored losc specs (included in full `make test`; red on LuaJIT but kept for
# completeness).
LOSC_SPECS := \
	$(TESTS_DIR)/losc_bundle_spec.lua \
	$(TESTS_DIR)/losc_init_spec.lua \
	$(TESTS_DIR)/losc_message_spec.lua \
	$(TESTS_DIR)/losc_packet_spec.lua \
	$(TESTS_DIR)/losc_pattern_spec.lua \
	$(TESTS_DIR)/losc_struct_spec.lua \
	$(TESTS_DIR)/losc_timetag_spec.lua \
	$(TESTS_DIR)/losc_types_spec.lua

# Every spec file.
ALL_SPECS := $(CORE_SPECS) $(LOSC_SPECS)

# Max number of concurrent nvim test processes for `make test`.
# Override with `make test TEST_JOBS=2`. Default 4 keeps the machine usable.
TEST_JOBS ?= 4

.PHONY: lint format format-check test test-core test-interactive

lint:
	luacheck $(PLUGIN_SRC) tests/

format:
	stylua $(PLUGIN_SRC) tests/

format-check:
	stylua --check $(PLUGIN_SRC) tests/

# Full test run: every spec (including vendored losc specs) with bounded
# concurrency. PlenaryBustedDirectory would spawn one nvim per spec all at
# once, which can crash the machine, so we schedule at most TEST_JOBS concurrent
# nvim processes instead. Each spec runs in its own `-u tests/minimal_init.lua`
# nvim (so the user's real config never loads) via plenary.busted.run directly;
# PlenaryBustedFile is avoided because it does not forward minimal_init to its
# subprocess. Output is redirected to a file first so it can be searched
# without a pipe (AGENTS.md).
test:
	@tmp=$$(mktemp -d); \
	printf '%s\n' $(addprefix $(CURDIR)/,$(ALL_SPECS)) | xargs -P$(TEST_JOBS) -I{} \
		sh -c 'h=$$(echo "{}" | md5sum | cut -c1-8); nvim --headless -u tests/minimal_init.lua -c "lua require(\"plenary.busted\").run(\"{}\")" > "$$1/out.$$h.log" 2>&1; echo $$? > "$$1/out.$$h.code"' _ "$$tmp"; \
	fails=0; \
	for f in $$tmp/out.*.code; do \
		[ -f "$$f" ] || continue; \
		if [ "$$(cat "$$f")" -ne 0 ]; then fails=$$((fails+1)); fi; \
	done; \
	echo "concurrency: $(TEST_JOBS)  spec files with failures: $$fails"; \
	rm -rf "$$tmp"; \
	[ "$$fails" -eq 0 ]

# Lightweight, green, project-only test run. Runs only the project's own
# specs (skipping the vendored, LuaJIT-red losc specs) in a single shell loop.
# Each spec needs its own nvim (plenary quits nvim after each file). Output is
# redirected to a file first so it can be searched without a pipe (AGENTS.md).
test-core:
	@fails=0; \
	for s in $(CORE_SPECS); do \
		nvim --headless -u tests/minimal_init.lua -c "lua require(\"plenary.busted\").run(\"$(CURDIR)/$$s\")" > /tmp/test-core.log 2>&1 || true; \
		line=$$(rg -i "failed" /tmp/test-core.log | rg -o "[0-9]+" | paste -sd, -); \
		echo "== $$s  [failed: $$line]"; \
		rg -i "failed" /tmp/test-core.log | rg -q ":[ \t]*0" || fails=$$((fails+1)); \
	done; \
	echo "spec files with failures: $$fails"; \
	[ $$fails -eq 0 ]

test-interactive:
	nvim -u tests/minimal_init.lua -c "lua require'plenary.test_harness'"
