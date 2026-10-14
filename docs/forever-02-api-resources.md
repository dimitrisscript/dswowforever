# Forever API Resources — What's Official, What's Not

> Short answer: there is **no single Blizzard-hosted "Forever API" web page**.
> Official truth lives in-game (`/api` + FrameXML) and in Blizzard's patch-note
> posts aggregated on Warcraft Wiki. Everything else is mirror or community.

## 1. Official (Blizzard)

- **In-game `Blizzard_APIDocumentation` (`/api`)** — the only complete,
  authoritative API reference. Generated docs ship with the client.
  Export or browse via `/api` on the beta client.
- **Exported FrameXML** — Blizzard UI source. Load order in `FrameXML.toc`;
  Forever overrides under `Camelot/` folders (e.g. `Blizzard_Professions/Camelot/`).
- **"How Midnight's Upcoming Game Changes Will Impact Combat Addons"**
  (`worldofwarcraft.blizzard.com/en-us/news/24244638`, Oct 2025) — design intent:
  addons must not automate combat decisions; cosmetics preserved.
- **"Forever 1.60.1 Beta Changes" + "WoW Forever Beta Development Notes"** —
  official per-build API patch notes, linked from
  `warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes`. Read every beta build note.
- **WoW UI Discord statement (Sep 15 2026, via Wowhead)** — Forever shares
  Mainline 12.1.5 UI architecture; Midnight disarmament incl. secrets is active.
- **UI Add-On Development Policy** (Blizzard forum, 2009, still referenced) +
  `develop.battle.net` contact. Note: `develop.battle.net` Game Data APIs are
  **web APIs, not the in-game Lua addon API** — don't confuse them.
- **Beta Known Issues forum thread** (Oct 1 2026) — e.g. 6-day SavedVariables
  outage (fixed Sep 23 build 70009). No blue post specifically on Forever
  addon restrictions as of mid-Oct 2026.

## 2. Semi-official aggregation (Warcraft Wiki)

- `warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes` — **the** Forever API diff page:
  TOC `16001`, `forever`/`camelot` game types, `WOW_PROJECT_CAMELOT (18)`,
  build history (70009 SV fix, 70170 constant, 70291 `forever` alias), full
  added/removed function lists (`C_GameRules`, `C_SkillInfo`, `C_PetInfo`,
  `C_SwingTimer`, `C_Flyout`, gamepad namespaces...).
- `.../Patch_1.60.1/API_changes/notes` — Beta 4 (70291) notes: trial-account
  addon messages blocked, `SendChatMessage EMOTE` needs hardware event,
  minimap-rotation leak fixed, new `FrameStrata` secret aspect, `require`
  renamed to `import`, `C_PvP.IsWarModeFeatureEnabled=false`, Edit Mode
  layouts per input style.
- `warcraft.wiki.gg/wiki/Secret_Values`, `/wiki/Patch_12.0.0/API_changes`,
  `/wiki/Patch_12.0.0/Planned_API_changes` — the Secrets spec (Midnight docs
  that apply to Forever): `issecretvalue`, `HasSecretValues`, aspects, anchors,
  `SecretArguments`/`SecretReturns` doc fields.
- `warcraft.wiki.gg/wiki/TOC_format`, `/wiki/Template:LatestPatchInfo` —
  suffix/game-type/interface table (`forever`/`camelot` → `16001`).

## 3. Source mirrors (ground truth you can grep)

- `github.com/Gethe/wow-ui-source` — branches `live` + `forever`;
  `Interface/AddOns/Blizzard_APIDocumentationGenerated/` (generated docs),
  `Interface/AddOns/Blizzard_ProjectConstants/Camelot/ProjectConstants.lua`
  (project constants). Pin branch + SHA + build when citing.
- `github.com/Ketho/BlizzardInterfaceResources` — GlobalStrings, AtlasInfo
  (via `wago.tools`), templates/mixins parsed from FrameXML; diff baseline.
- `wago.tools` — Atlas/GlobalStrings database behind `docs.wago.io`.

## 4. Community (tested on beta, not authoritative)

- `wowforeverguides.com/addons/developers` (+ `/patterns`, `/api-cheatsheet`,
  `/pitfalls`, `/code-templates`, `/ai-prompts`, `/forever-beacon`) — system
  prompt + starter files + verification checklist. Best practical companion.
- `wowforevertierlist.com/addons/restrictions`, `/addons/how-to-install` —
  restriction/install guides with explicit confirmed-vs-reported labeling.
- `wow-forever.gg` (WoW Forever Builds & Tools) — per-build reports
  (e.g. 70291 vs 70245: spells/items/zones/talents).
- `zol-wow.github.io/QUI/blizzard/forever-support-strategy.html` — real
  Forever port audit: loaded Camelot UI topology, secure-snippet policy,
  corpus pinning method. Copy its "pin + separate corpus" discipline.
- `theforeverera.com/en/addon/` — shipped Forever addon example
  (1.60.1 / 16001, `_classic_beta_` path).
- CurseForge `Forever` flavor / game version `1.60.1` + Wago flavor —
  distribution-side signal that a file was deliberately built for Forever.

## 5. Gaps to recheck at launch (Nov 4)

- Launch folder name (`_classic_beta_` is beta-only; `_forever_` seen on PTR).
- Interface number move off `16001`.
- `camelot` → `forever` rename (TOC suffix, `AllowLoadGameType`, constants).
- `loadstring_untainted` / secure-snippet status; WeakAuras/DBM module status.
