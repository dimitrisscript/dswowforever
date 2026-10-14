# Forever Secrets + Verification Checklist

> Source: Blizzard Midnight combat-addon article + Secrets docs, applied to
> Forever per Sep 15 Discord statement. No Forever-specific restricted-function
> list published. Treat below as "inherited retail behavior, must test on Forever".

## 1. Secret Values — rules

- A Secret can be held and passed to some Blizzard functions, but not inspected:
  concat / tonumber / arithmetic on a Secret errors.
- Gentle cases: different-type Secret compare → `false` (not error),
  two Secret nils equal, `if x then` still works as nil test.
- Tests: `issecretvalue(v)`, `HasSecretValues(obj)`, `HasSecretAspect(obj, aspect)`,
  `IsAnchoringSecret(frame)`. `SetToDefaults()` clears Secret state.
- Spread: Secret into texture/frame → object becomes Secret; `SetShown` marks
  only Shown aspect; anchors propagate down to children, never up to parents.

Observed on Forever beta 69913: `UnitHealth("player")` secret number
(`type()=="number"` but `+` fails), names secret strings, `UnitCanAttack` /
`UnitExists` secret booleans. Retest every build.

## 2. What's locked

- Combat log: `COMBAT_LOG_EVENT_UNFILTERED` registration throws; Combat Log
  chat tab strings unparsable. No damage/healing meter from log.
- In instance: chat arrives Secret, addons may not send addon messages or
  chat to other players; creature names/GUIDs/IDs Secret (no longer combat-dependent).
- Health/power/casts/auras (after Midnight alpha relaxations):
  - Secret: `UnitHealthPercent`, `UnitHealthMissing`, `UnitPowerPercent`,
    `UnitPowerMissing`, primary resources, other units' casts, aura *contents*.
  - NOT secret: `UnitHealthMax`/`UnitPowerMax` for player units, player secondary
    resources (combo points incl.), own + pet casts even in combat, aura *lists*
    + `UNIT_AURA` event + helper fns (instance IDs, expiration flag, app count,
    dispel color).
- Protected-call failure: "Interface action failed because of an AddOn" with
  NO Lua error; `pcall` won't clear; counter clears on full restart, not `/reload`.
  Avoid: `ChatFrame_OpenChat`, `ChatEdit_ActivateChat`,
  `C_SuperTrack.SetSuperTrackedUserWaypoint`, writing secure attrs onto
  Blizzard unit frames. Map pins via `C_Map.SetUserWaypoint(UiMapPoint)`;
  shift-click links via `HandleModifiedItemClick`.

## 3. Lua 5.1 + API migration

- No `goto`, `//`, bitwise ops, `_ENV`. Bit via `bit.band/bor/lshift`.
  No `require/dofile/loadfile/io/os` — TOC is the loader.
- Missing on 69913 (use C_ + async): `GetSpellInfo`, `GetItemInfo`,
  `GetSpellBookItemName`, `GetNumTalentTabs`, `GetTalentInfo`, `GetNumSkillLines`.
  ```lua
  local info = C_Spell and C_Spell.GetSpellInfo(spellID) -- table or nil
  if not info then C_Spell.RequestLoadSpellData(spellID) end -- + SPELL_DATA_LOAD_RESULT
  ```
- Removed retail systems (1.60.1 diff vs 12.1.5: +176 fns, -10 fns, -1041 globals):
  Encounter Journal, Challenge Mode, housing helpers, Account Store, transmog
  weapon opts. Nil-guard everything retail-only.
- Added for Forever-style: flyout ns, Classic skill lines, pet happiness/loyalty/
  training pts, ammo counts, low-rank spell tests, temp weapon enchants, surname
  helpers, gamepad namespaces, ruleset detection (Normal/PvP/RP/Hardcore).

## 4. File verification checklist (run per AI draft)

- [ ] `## Interface: 16001` present (alone or multi-client line)
- [ ] No `goto // _ENV require io os` (Lua 5.1)
- [ ] Every file opens `local addonName, ns = ...`; shared state on `ns`; frames named `DSWF_*` or `nil`
- [ ] C_ lookups with nil checks + load requests + result events
- [ ] No `COMBAT_LOG_EVENT_UNFILTERED` / `CombatLogGetCurrentEventInfo`
- [ ] Health/power/names guarded by `issecretvalue` before math/print/branch; StatusBar fed directly
- [ ] No Classic branch on `WOW_PROJECT_ID` alone; use `WOW_PROJECT_CAMELOT` + build probe
- [ ] No secure snippets / secure attrs on Blizzard frames; own buttons only
- [ ] SavedVariables touched only in `ADDON_LOADED(addonName)`, never file scope
- [ ] `InCombatLockdown()` guard + `PLAYER_REGEN_ENABLED` queue for show/hide/move
