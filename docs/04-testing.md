# 04 — Testing (Classic Addons)

Three tiers observed in the wild (Mechanic docs + community):

| Tier | Speed | Needs WoW? | Best for |
|---|---|---|---|
| Sandbox stub | ~30 ms | No | Pure logic, CI |
| Desktop busted | ~5 s | No | Integration, mocks |
| In-game | ~30 s | Yes | Real API, UI, secrets |

Recommendation: sandbox/desktop for `Core/` logic, in-game only for
live API / frames / combat.

## 1. Desktop: busted + Lua 5.1

- Framework: `lunarmodules/busted` — `describe` / `it` / `before_each`,
  `assert.equals`, `assert.is_true`, tags, TAP/JSON output, CI-friendly.
- Install: `luarocks install busted` (needs LuaRocks; Lua 5.1 to match WoW).
- Layout: `spec/` or `Tests/` with `*_spec.lua` (`busted` pattern default `_spec`).
- Run: `busted`, `busted -p my_spec`, `busted --coverage` (with `luacov`).

Minimal example:

```lua
-- spec/hello-world_spec.lua
describe("Hello World", function()
  it("concats", function()
    assert.equals("Hello World", "Hello".. " " .. "World")
  end)
end)
```

Mock WoW globals before `require`:

```lua
_G.LibStub = function() return { Register = function() end } end
_G.C_AddOns = { GetAddOnMetadata = function() return "1.0.0" end }
_G.CreateFrame = function() return {} end
```

Load addon files with namespace shim (`local _, ns = ...` pattern):

```lua
-- helper to load file with varargs like WoW does
local function loadAddonFile(path, name, ns)
  local chunk = assert(loadfile(path))
  setfenv(chunk, setmetatable({ ... }, { __index = _G })) -- Lua 5.1
  -- or call chunk(name, ns) on Lua 5.1 with vararg wrapper
end
```

Simpler: structure `Core/` as pure functions with no `_G` at load time,
pass WoW APIs as params for easy injection.

## 2. Docker: `runeberry/wow-addon-container`

- Image: Alpine + Lua 5.1.5 + LuaRocks + `busted` + `luacov` +
  `luacov-console` + `luacov-reporter-lcov` + `luabitop` + `make`.
- Use: mount addon dir, `docker run -it -v ${PWD}:/addon ...`, `busted`.
- Goal: reproducible CI without local Lua setup. 30-min setup claim holds
  for pure-Lua logic; WoW API must still be mocked.

## 3. In-game: WoWUnit

Two lineages share the name — both same idea:

- `Jaliborc/WoWUnit` (GitHub, maintained example):
  ```lua
  -- ## OptionalDeps: WoWUnit  in .toc
  if WoWUnit then
    local AreEqual = WoWUnit.AreEqual
    local Tests = WoWUnit("DSWowForever", "PLAYER_LOGIN")
    function Tests:MathWorks()
      AreEqual(4, 2+2)
    end
  end
  ```
  Methods: `AreEqual(a,b)`, `IsTrue/IsFalse`, `Exists`, `Replace(tbl,name,fn)`,
  `Enable/Disable`. Group runs at startup + listed events.

- `WoWUnit by Feithar` (CurseForge / WowAce):
  ```lua
  WoWUnit:AddTestSuite("DSWF_Suite", {
    mocks = { UnitName = function() return "Soandso" end },
    setUp = function() return {} end,
    testExample = function(ctx)
      assert(UnitName("player")=="Soandso")
    end,
  })
  -- /wowunit DSWF_Suite
  ```

Use WoWUnit for: event order, frame visibility, secret values
(`issecretvalue`), combat lockdown behavior — things mocks lie about.

## 4. Sandbox pattern (Mechanic-inspired, no dependency)

1. `sandbox.generate`-style: parse `Blizzard_APIDocumentationGenerated`
   or hand-write `stubs/wowapi.lua` (~50 fns you use, not 5000).
2. `sandbox.test`-style: build one Lua file = stubs + `Core/*.lua` + `*_spec.lua`.
3. Run with plain `lua5.1`.

Keep stubs checked in so CI is hermetic.

## 5. CI suggestion

```yaml
# .github/workflows/test.yml
- uses: actions/checkout@v4
- run: luarocks install busted
- run: busted -v
- run: wowlua_ls check .
```

Fail on busted error, warn on LS diagnostics initially.

## 6. What to test for Classic

- SavedVariables migration, slash parsing, event registration.
- Money/XP formatting, bag/slot math, cooldown math (pure).
- Frame pooling, anchor math with mocked `CreateFrame`.
- Do NOT assert exact Blizzard text; GlobalStrings change per patch.
