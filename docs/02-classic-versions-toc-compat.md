# 02 — Classic Versions, Interface Numbers, TOC Compat

Source: `warcraft.wiki.gg/wiki/TOC_format`,
`warcraft.wiki.gg/wiki/Getting_the_current_interface_number`,
`better-addons.com/toc-format`.

Values below are contributor-maintained and drift with patches.
Always confirm with `/dump select(4, GetBuildInfo())`.

## 1. Current Interface numbers (2026 research snapshot)

| Client | Patch example | `## Interface` |
|---|---|---|
| Retail Standard | 12.0.1 / 12.1.0 | `120001` / `120100` / `120105` (PTR/Test) |
| Mists Classic | 5.5.4 | `50504` |
| Cata Classic | 4.4.x | `40401` / `40402` |
| Wrath Classic | 3.4.x | `30403` / `30405` |
| Wrath Titan Reforged | — | `38002` |
| TBC / Anniversary | 2.5.6 | `20506` |
| Classic Era / Hardcore | 1.15.8 / 1.15.9 | `11508` / `11509` |
| Forever Beta/Test | 1.6x | `16001` |

For `dswowforever` Classic Era: use `11509` today.

Multi-flavor single TOC (supported on modern clients):

```toc
## Interface: 120100, 50504, 11509
```

Older guidance required separate TOCs per flavor to avoid
“out-of-date” flag. Prefer comma list where supported, separate TOCs
when code/XML diverges.

## 2. TOC file suffixes

Client searches flavor-suffixed TOC first, falls back to `AddonName.toc`.

Modern (`_` style):

| Suffix file | Loads on |
|---|---|
| `MyAddon_Standard.toc` | Midnight Retail |
| `MyAddon_Mists.toc` | MoP Classic |
| `MyAddon_Cata.toc` | Cata Classic |
| `MyAddon_Wrath.toc` | Wrath / Titan Reforged |
| `MyAddon_TBC.toc` | TBC / Anniversary |
| `MyAddon_Vanilla.toc` | Classic Era pre-expansion |
| `MyAddon_Classic.toc` | Any Classic family |
| `MyAddon_Mainline.toc` | Any Retail family |
| `MyAddon_Forever.toc` / `_Camelot.toc` | Forever |

Legacy (`-` style, still recognized): `-Mainline`, `-Classic`, `-BCC`,
`-WOTLKC`, `-Cata`. Prefer `_` for new work.

Example layout:

```text
DSWowForever/
  DSWowForever.toc          # fallback
  DSWowForever_Classic.toc  # Classic family
  DSWowForever_Mainline.toc # Retail family (if ever)
  Core.lua
```

## 3. Flavor gating in code

```lua
-- constants defined by client
-- WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC, etc.
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
  -- Era path
else
  -- Retail / other
end
```

TOC directive (10.2.7+):

```toc
## AllowLoadGameType: classic
## AllowLoadGameType: mainline, classic
```

Use for dependencies / ignoring wrong-flavor deps.

## 4. Minimal Era TOC

```toc
## Interface: 11509
## Title: DS Wow Forever
## Notes: Classic Era helpers
## Author: dswowforever
## Version: 0.1.0
## SavedVariables: DSWowForeverDB
## OptionalDeps: BugSack, WoWUnit
Core.lua
```

Checklist:
- [ ] Interface matches Era (`/dump select(4, GetBuildInfo())`)
- [ ] Unique global prefix (`DSWF_`, `DSWowForever_`)
- [ ] No Retail-only `C_*` without nil guard
- [ ] Test with “Load out of date addons” OFF to catch mismatch
