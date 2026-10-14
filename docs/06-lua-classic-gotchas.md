# 06 — Lua and Classic Gotchas

## 1. Lua version

- WoW = **Lua 5.1** (plus Blizzard sandbox). No `goto`, no `//`, no `<<`,
  no `utf8` lib. Use `bit` via `bitlib` where needed (`luabitop` in tests).
- `setfenv` / `getfenv` exist (removed in 5.2+). Avoid unless sandboxing.
- `require` / `dofile` restricted; addons load via TOC file list in order.
- 1-indexed tables, `ipairs` vs `pairs` cost matters in combat logs.

Structure to stay testable:

```lua
local ADDON_NAME, ns = ...
ns.Util = {}
function ns.Util.Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end
```

No WoW calls at file top-level except table defs; do work on events.

## 2. Sandbox / taint / secure frames

- All addon code shares globals — prefix everything: `DSWF_`, `DSWowForeverDB`.
- **Taint:** touching secure frames (action buttons, unit frames) from
  addon path during combat can block actions. Keep combat paths minimal,
  use `InCombatLockdown()` guards.
- **Combat lockdown:** many `SetAttribute`, `Show/Hide`, anchor changes
  fail in combat for protected frames. Queue for `PLAYER_REGEN_ENABLED`.
- Validate inputs from chat/addon messages — never `loadstring` remote code.

```lua
if InCombatLockdown() then
  ns.pendingRefresh = true
  return
end
ns.frame:Show()
```

## 3. Classic vs Retail API

- Classic lacks many `C_*` (e.g. newer `C_AddOns`, `C_Item`, `C_Map` subsets).
  Always nil-guard:
  ```lua
  local name = (C_AddOns and C_AddOns.GetAddOnMetadata)
    and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    or GetAddOnMetadata(ADDON_NAME, "Version")
  ```
- Events differ: verify in Era FrameXML, not Retail wiki. Use `/etrace`
  to confirm `PLAYER_LOGIN`, `ADDON_LOADED`, `BAG_UPDATE`, etc.
- `WOW_PROJECT_ID` check for forks (see `02-*`).
- Fonts/textures/atlas names differ; don’t hardcode Retail atlas.
- SavedVariables path is per-flavor:
  `WTF/Account/.../SavedVariables/DSWowForever.lua` under `_classic_era_`.

## 4. Performance

- `OnUpdate` throttling: accumulate `elapsed`, update at 0.1–0.25 s, not per frame.
- Reuse tables/frames; avoid `table.concat` in hot combat-log path without buffering.
- `debugprofilestop()` to measure; WoWUnit `RunTest` example uses it for timing.

## 5. Debugging checklist

- [ ] `/console scriptErrors 1` or BugSack on
- [ ] Repro with only this addon enabled
- [ ] `/dump DSWowForeverDB` after reload/logout (SV save timing)
- [ ] `/fstack` to find frame name / strata culprit
- [ ] `/etrace` to confirm event fires in Era
- [ ] Check `11509` vs Retail API misuse first — most common Classic bug
