# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## Notes on `make test`

`make test` runs every spec file with bounded concurrency (default 4 parallel
nvim processes; override with `make test TEST_JOBS=N`). It is heavier than
`make test-core`, which runs only the project's own (green) specs sequentially —
prefer `test-core` for a quick check. Wrap with an OS-level `timeout` if you want
to bound the runtime. Avoid leaving interrupted runs behind; orphaned nvim
processes can accumulate and stall the machine.

## Currently-failing tests (pre-existing, unrelated to feature work)

The vendored OSC library tests are red on this machine (LuaJIT vs the Lua 5.3
features the library feature-detects). Known offenders:

- `tests/plenary/losc_types_spec.lua` — integer/float pack-roundtrip and the
  `I` (inf) case (`assert.equals(math.huge, value)`).
- Related losc specs are also failing.

These are NOT regressions from recent commits. If you touch vendored code under
`lua/tidal/lib/losc/`, expect these to stay red.

## Commands

```sh
make lint          # luacheck — the gate for changes
make format        # stylua (writes)
make format-check  # stylua --check — the gate for changes
make test          # full suite, bounded concurrency (TEST_JOBS, default 4)
```

- Always run `make lint` and `make format-check` after editing Lua. Do not rely
  on `make test` as the sole CI signal (it is currently failing and heavy).

## Conventions

- Neovim plugin. Requires `nvim >= 0.10`. Uses `vim.uv` (not `vim.loop`).
- **Use `vim.schedule(...)`** (wrap in `vim.schedule_wrap` for callbacks) whenever
  Neovim API functions (e.g. `nvim_buf_*`, `nvim_notify`, `nvim_buf_set_extmark`)
  are invoked from a libuv callback or other fast-event context. This includes
  `vim.uv` timers/sockets — notably the OSC UDP `recv_start` handler in
  `core/osc.lua`. Calling nvim API directly there raises
  `E5560: ... must not be called in a fast event context`. Prefer deferring the
  whole handler body with `vim.schedule` rather than only the notify calls.
- Style: `stylua.toml` (2-space indent, 120 col width).
- LuaFmt/luacheck globals and ignores are declared in `.luacheckrc` (module-level
  forward references in `core/taptempo.lua` are declared there).
- `/tmp/opencode` is available for scratch work.
- This is a fork of `grddavies/tidal.nvim`; upstream remote is `grddavies`.
