# 03 — Tools and Dev Setup (Classic)

## 1. Editor: VSCode (recommended)

Extensions found in research:

- **WoW Lua Language Server (`TradeSkillMaster.wowlua-ls`)** — Recommended 2026 pick.
  - 9,000+ WoW API stubs for retail/classic/era, 70 diagnostics,
    event typing, XML frame scanning.
  - Zero config: open addon folder, it scans `.lua`.
  - Optional `.wowluarc.json`:
    ```json
    {
      "flavors": ["classic"],
      "ignore": ["Libs/"]
    }
    ```
  - CLI for CI: `wowlua_ls check path/to/addon` (non-zero on diagnostics).
  - Docs: `tradeskillmaster.github.io/wowlua-ls`, repo `TradeSkillMaster/wowlua-ls`.
  - Also available for JetBrains 2025.2+ via LSP4IJ.
- **WoW Bundle (Septh)** + **WoW TOC (Stanzilla)** + **Ketho's WoW API** —
  classic Reddit guide stack (`r/wowaddondev`, SoD base, still valid):
  Lua grammar + WoW API knowledge, `.toc` colorization.
- **Lua (Sumneko)** — general Lua IntelliSense if not using wowlua-ls.
- **EmmyLua (`tangzx.emmylua`)** — completion + remote debug; needs debugger
  injection, less WoW-specific than wowlua-ls.

Pick: `wowlua-ls` + `WoW TOC`. Add Emmy/Sumneko only if you need them.

Other editors:
- ZeroBrane Studio (Lua 5.1 live coding), Notepad++, Vim `wowlua.vim`,
  AddOn Studio (Visual Studio based IDE, `addonstudio.org`).

## 2. In-game dev addons

- **BugSack + BugGrabber** — captures Lua errors; alternative:
  `/console scriptErrors 1`.
- **WowLua** — in-game REPL + multi-page editor. Eval snippets without reload.
- **DevTools / DevSuite (`kapresoft`)** — `2026-10-01` build supports Classic:
  Lua eval dialog, `tr(...)` trace via LibTraceKit, `/etrace` presets,
  hover frame inspect, `/fstack` keybind, DebugChatFrame tab, `/devsuite`.
- **TextureAtlasViewer** — find atlas names for Classic UI.
- **LuaBrowser** — browse `_G`, tables, widgets.

## 3. Core slash commands

- `/reload` — reload UI after code edit. Put on hotkey macro. Note: modern
  Era recognizes TOC directive / new file changes on reload (since 1.14.0).
- `/dump <expr>` — inspect value/table.
- `/etrace` — live event log.
- `/fstack` — frame stack under mouse (Blizzard tool).
- `/api` — Blizzard_APIDocumentation viewer.
- `/console scriptErrors 1` — show errors in-game.

Workflow: edit in VSCode → `/reload` → reproduce → BugSack → `/dump` →
fix → `/reload`. Disable unrelated addons to speed load.

## 4. FrameXML extraction / reference

- Export from client (Blizzard tool) or clone:
  `Gethe/wow-ui-source`, `Ketho/wow-ui-source-vanilla`.
- `rg -n "MyAPI|MyEvent" wow-ui-source-vanilla/` to see Blizzard usage.
- `Ketho/BlizzardInterfaceResources` for GlobalStrings, Atlas, mixins.

## 5. Suggested repo layout

```text
DSWowForever/
  DSWowForever.toc
  Core.lua
  UI.lua
  Libs/              # ignored by LS, filled by packager externals
  Tests/             # busted specs (see 04-testing.md)
  docs/              # this research
  .pkgmeta           # externals (see 05-packaging-publishing.md)
  .wowluarc.json
  .github/workflows/release.yml
```
