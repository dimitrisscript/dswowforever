# Forever Readiness — Beta to Launch

> Beta: Sep 17–Oct 21 2026. Launch: Nov 4 2026 3pm PST. Level 60 cap, fresh realms.
> Today: Oct 14 2026 — prepare on beta, keep launch-flexible.

## 1. Forever is Mainline, not Era

- Internal game type: `camelot` (to be renamed before launch per Blizzard).
- Family: Mainline. Shares vast majority of Retail 12.1.5 APIs + Midnight
  addon disarmament (secrets included). Do NOT port Era combat code.
- Sources: Blizzard WoW UI Discord Sep 15 (via Wowhead), Sep 17 Q&A stream,
  `warcraft.wiki.gg/wiki/TOC_format`, `wowforeverguides.com/addons/developers`.

## 2. Interface / TOC

- Beta: `## Interface: 16001` (Warcraft Wiki TOC table, Forever Beta row).
- Era is `11509`, Midnight `120100` — do not use for Forever.
- Confirm on your client: `/dump select(4, GetBuildInfo())`
- Version-range probe: `local v = select(4, GetBuildInfo()); Forever = v > 16000 and v < 20000`
- Files:
  - `DSWowForever_Camelot.toc` — Forever (wiki-listed suffix)
  - `DSWowForever_Forever.toc` — alias, ship both if packager splits
  - `DSWowForever.toc` — fallback
- Directives:
  ```toc
  ## Interface: 16001
  ## AllowLoadGameType: camelot
  ## ExcludeLoadGameType: standard, classic
  ```
  Exclusion needed because old clients load unknown game types anyway.
- Project constant (build 70170+, Oct 1): `WOW_PROJECT_CAMELOT = 18`
  ```lua
  local isForever = (WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
    or (select(4, GetBuildInfo()) > 16000 and select(4, GetBuildInfo()) < 20000)
  ```
  Do NOT branch on `WOW_PROJECT_ID == 1` alone (build 69913 reported 1).

## 3. Install path

- Beta: `World of Warcraft\_classic_beta_\Interface\AddOns\DSWowForever\` (`WowB.exe`)
- Launch folder name NOT confirmed — recheck Nov 4 via Battle.net
  App → Game Version → Forever → cog → Show install folder.
- Rules: folder name == TOC basename, TOC directly inside, no wrapper
  (`AddOns\DSWowForever\DSWowForever.toc`, not `... \DSWowForever-1.0\...`).
- Client reads folders only at startup — restart after adding.
- Enable at character select → AddOns. Check CurseForge file tagged
  `Forever` / `1.60.1`, or `.toc` lists `16001`.

## 4. What to build (safe vs risky)

- Safe: bags, tooltips, map pins (`C_Map.SetUserWaypoint`), minimap button,
  quest notes, vendor/mail helpers, cosmetic frames, own-player resource bar.
- Risky/broken: damage meters (`COMBAT_LOG_EVENT_UNFILTERED` throws),
  boss mods with timers, auto-mark (creature GUID secret in instances),
  instance chat send, WeakAuras-style triggers, secure-snippet click-cast
  (failed to compile on 69913 — retest, don't depend on it).
- Built-in: damage meter + Cooldown Manager per Sep 17 stream; swing timer
  "perhaps coming soon". Don't replace them.

## 5. Pre-launch checklist for this repo

- [ ] Template loads on beta with zero Lua errors (all addons off except this)
- [ ] `/dump select(4, GetBuildInfo())` recorded + TOC updated if moved off 16001
- [ ] `wowlua_ls check` clean on Mainline flavor
- [ ] `busted` green
- [ ] SavedVariables survive logout → login (beta bug fixed Sep 23 build, re-verify)
- [ ] Zip contains only runtime files; packager `-S` tested
