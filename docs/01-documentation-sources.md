# 01 — Documentation Sources (Classic)

Canonical starting point: `warcraft.wiki.gg/wiki/World_of_Warcraft_API`.
It states the WoW API is used by Blizzard's Lua UI and is officially
documented in `Blizzard_APIDocumentation`, accessible in-game via `/api`.

## 1. Wikis

- **Warcraft Wiki (current):** `warcraft.wiki.gg`
  - `World_of_Warcraft_API` — entry hub, C_* namespaces
  - `World_of_Warcraft_API/Alphabetic` — full function list
  - `Widget_API` — `CreateFrame()` objects, methods, scripts
  - `TOC_format` — modern TOC, `Interface`, suffixes, `AllowLoadGameType`
  - `Getting_the_current_interface_number` — `/dump select(4, GetBuildInfo())`
  - `XML_user_interface`, `XML` — `Ui`, `Frame`, `Scripts`, `Layers`, templates
  - `FrameXML_functions` + `FrameXML_functions/Classic` — Classic comparison
  - `Category:FrameXML_documentation` — FrameXML-provided vs C API
  - `Create_a_WoW_AddOn_in_15_Minutes` — `/reload`, `BugSack`, `/dump`, `/etrace`, `/fstack`, FrameXML reference advice
- **Wowpedia (legacy mirror):** `wowpedia.fandom.com/wiki/TOC_format`
  - Still useful for old suffix table: `_Mainline`, `_Cata`, `_Wrath`, `_TBC`, `_Vanilla`.
- **AddOn Studio wiki:** `addonstudio.org/wiki/WoW:TOC_format`
  - Documents fallback: `MyAddon.toc` fallback, edition-specific TOC override.

Use Warcraft Wiki first in 2026; fall back to Wowpedia for old patches.

## 2. In-game authoritative docs

- `/api` — opens `Blizzard_APIDocumentation` viewer (in-game generated docs).
- `/dump select(4, GetBuildInfo())` — prints your client's exact Interface number.
- `WTF/Config.wtf` → `lastAddonVersion` CVar — most authoritative after at least one login.
- Exported FrameXML: Blizzard UI code export from client, or GitHub mirrors below.

When wiki is ambiguous: read FrameXML. Example pattern:
search `GetUnitSpeed`, `C_AddOns.*`, `EventRegistry` in FrameXML to see real usage,
nil handling, and Classic guards.

## 3. FrameXML source mirrors

- `github.com/Gethe/wow-ui-source`
  - Branches per client: `live`, Classic Era, PTR. Path:
    `Interface/AddOns/Blizzard_APIDocumentationGenerated`
  - `FrameXML/FrameXML.toc` shows load order (`UIParent.xml` etc.).
- `github.com/Ketho/wow-ui-source-vanilla`
  - Classic Era mirror for GitHub code search.
- `github.com/Ketho/BlizzardInterfaceResources`
  - Dumped via KethoDoc: GlobalStrings, AtlasInfo (from `wago.tools`),
    templates/mixins parsed from FrameXML.

Tip: clone Era mirror locally and `rg` it. Faster and exact vs wiki lag.

## 4. API reference aggregators

- `wago.tools` — database behind `docs.wago.io`, Atlas/GlobalStrings source.
- `docs.wago.io` — Wago publishing API + game-flavor notes.
- `better-addons.com/toc-format`, `better-addons.com/publishing` — modern
  TOC + packager guide with Interface table.

## 5. How to verify a Classic API

1. Check Warcraft Wiki page; note `Patch changes` / flavor badges.
2. `rg` same name in Era FrameXML mirror.
3. In-game: `/dump FunctionName` or `WowLua` eval, `/etrace` for events.
4. Guard code with `WOW_PROJECT_ID` / nil checks (see `02-*`).
