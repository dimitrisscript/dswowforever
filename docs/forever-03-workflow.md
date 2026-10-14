# Forever Dev Workflow — How to Know What to Write

> No single Blizzard web API page. Truth = client (`/api` + FrameXML) +
> official build notes. Wiki/mirrors = index. In-game probe = verdict.

## 1. Confirm your build (every session)

```text
/dump select(4, GetBuildInfo())
-- Expect 16001 on beta. If it moved, update TOC first.

/dump WOW_PROJECT_ID
/dump WOW_PROJECT_CAMELOT
-- Forever: 18 on builds with the constant (70170+). Older 69913 reported 1 — don't branch on 1 alone.

/dump C_Secrets and HasSecretRestrictions and C_Secrets.HasSecretRestrictions()
-- Tells you if secret restrictions are enabled on this build.
```

Lua equivalent for code:

```lua
local build = select(4, GetBuildInfo())
local isForever = (WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
  or (type(build) == "number" and build > 16000 and build < 20000)
```

## 2. Look up the API (official order)

1. **`/api`** in-game — `Blizzard_APIDocumentation` viewer. Search the exact
   `C_*` namespace + function. Check `SecretArguments` / `SecretReturns` fields.
2. **FrameXML grep** (or `Gethe/wow-ui-source` `forever` branch):
   ```bash
   rg -n "GetSpellInfo|GetItemInfo|CooldownViewer|AllowLoadGameType" --glob '*.lua' --glob '*.xml' --glob '*.toc'
   ```
   Read how Blizzard's own Camelot UI calls it — args, nil handling, events.
3. **`warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes`** — per-build added/removed
   lists + `.../notes` for behavior (e.g. 70291 `forever` alias, EMOTE hardware
   event, `FrameStrata` secret aspect).

## 3. Probe values (secrets + availability)

```text
/dump UnitName("player")
/dump issecretvalue(UnitName("player"))
/dump UnitHealth("player"), issecretvalue(UnitHealth("player"))
/dump C_Spell.GetSpellInfo(12345)
/dump C_Item.GetItemInfo(12345)
/dump CombatLogGetCurrentEventInfo
-- Last one should be nil/unavailable on Forever. Do NOT build on it.
```

Async pattern (data not cached returns nil):

```lua
local info = C_Spell and C_Spell.GetSpellInfo(spellID)
if info == nil and C_Spell and C_Spell.RequestLoadSpellData then
  C_Spell.RequestLoadSpellData(spellID)
  -- wait for SPELL_DATA_LOAD_RESULT
end
```

Secret-safe StatusBar (pass through, don't math):

```lua
if type(issecretvalue) ~= "function" or not issecretvalue(hp) then
  -- only then compare/print
end
bar:SetMinMaxValues(0, maxHp) -- maxHp itself already probed
bar:SetValue(hp)
```

## 4. Events + frames

```text
/etrace
-- Filter to your event (e.g. PLAYER_LOGIN, UNIT_AURA, SPELL_DATA_LOAD_RESULT).
-- If COMBAT_LOG_EVENT_UNFILTERED errors on register, stop — combat-log design is dead.

/fstack
-- Hover the frame. Gives name/strata/owner. Use it before skinning anything.

/dump DSWowForeverDB
-- After logout→login. If empty, you hit the beta SV bug or file-scope init.
```

## 5. Copy working ports before inventing

- Questie / Details! / Auctionator / ElvUI Forever files — quest/bag/meter patterns that survived secrets.
- `zol-wow.github.io/QUI/blizzard/forever-support-strategy.html` — Camelot topology gaps
  (`GroupFinder_VanillaStyle`, `Professions/Camelot`, `Collections` overrides).
- `theforeverera.com/en/addon/` — minimal shipped 16001 example.

## 6. Local gates (before `/reload`)

```bash
wowlua_ls check DSWowForever
busted -v
```

`wowlua_ls` catches Era globals (`GetSpellInfo`); `busted` catches logic.
In-game `/reload` catches the rest. Full restart (not `/reload`) clears the
"Interface action failed because of an AddOn" counter.

## 7. Per-draft checklist

- [ ] Build recorded (`GetBuildInfo` 4th return)
- [ ] `/api` confirms every `C_*` used
- [ ] FrameXML shows a Camelot caller, or probe confirms presence
- [ ] Secrets guarded before math/compare/print/concat-to-number
- [ ] No `COMBAT_LOG_EVENT_UNFILTERED`, no secure attrs on Blizzard frames
- [ ] SV init only in `ADDON_LOADED`, lockdown queue via `PLAYER_REGEN_ENABLED`
