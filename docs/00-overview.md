# WoW Classic Addon Research — Overview

Repo: `dswowforever` — currently empty except `README.md`.
Date: 2026-10-14. Target: WoW Classic Era addons (Lua 5.1 + FrameXML).

## What is in `docs/`

1. `01-documentation-sources.md` — canonical API docs, FrameXML source mirrors
2. `02-classic-versions-toc-compat.md` — Interface numbers, TOC suffixes, flavor checks
3. `03-tools-devsetup.md` — VSCode / IDE, in-game dev addons, slash commands
4. `04-testing.md` — busted offline, Docker container, WoWUnit in-game
5. `05-packaging-publishing.md` — BigWigs packager, .pkgmeta, CurseForge / WoWInterface / Wago
6. `06-lua-classic-gotchas.md` — Lua 5.1 limits, taint, combat lockdown, Classic vs Retail

## Quick start for this repo

```toc
## Interface: 11509
## Title: DS WoW Forever
## Notes: Classic Era addon
## Author: dswowforever
## Version: 0.1.0
## SavedVariables: DSWowForeverDB
Core.lua
```

```lua
-- Core.lua
local ADDON_NAME, ns = ...
ns.frame = CreateFrame("Frame")
ns.frame:RegisterEvent("ADDON_LOADED")
ns.frame:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON_NAME then
    print(ADDON_NAME.." loaded")
  end
end)
```

Install test copy to:
`World of Warcraft\_classic_era_\Interface\AddOns\DSWowForever\`
then `/reload` in-game.

## Sources used

- `warcraft.wiki.gg/wiki/World_of_Warcraft_API`
- `warcraft.wiki.gg/wiki/TOC_format`
- `warcraft.wiki.gg/wiki/Getting_the_current_interface_number`
- `github.com/Gethe/wow-ui-source`, `github.com/Ketho/wow-ui-source-vanilla`
- `github.com/TradeSkillMaster/wowlua-ls`
- `github.com/lunarmodules/busted`, `github.com/runeberry/wow-addon-container`
- `github.com/Jaliborc/WoWUnit`, CurseForge WoWUnit page
- `github.com/BigWigsMods/packager`, `warcraft.wiki.gg/wiki/Using_the_BigWigs_Packager_with_GitHub_Actions`
- `docs.wago.io`, `better-addons.com`
