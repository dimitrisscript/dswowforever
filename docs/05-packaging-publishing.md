# 05 — Packaging and Publishing (Classic)

Standard 2026 path: **BigWigs packager** + GitHub Actions tag release.

## 1. Targets

- **CurseForge** — largest client reach (CurseForge app, Overwolf).
- **Wago Addons (`addons.wago.io`)** — modern API, `X-Wago-ID`.
- **WoWInterface** — classic audience, numeric ID in URL.
- **GitHub Releases** — fallback + nolib zips.

All three accept same zip; packager uploads in one run if tokens present,
skips missing ones.

## 2. TOC project IDs

```toc
## X-Curse-Project-ID: 123456
## X-WoWI-ID: 5678
## X-Wago-ID: aBcDeFgH
## Interface: 11509
```

- Curse ID: number on project page.
- WoWI ID: number in `wowinterface.com/downloads/info5678-...`.
- Wago ID: 8-char string on developer dashboard, also add to `.toc`.

## 3. `.pkgmeta` (externals)

Controls file copy + lib checkout. Minimal:

```yaml
package-as: DSWowForever

ignore:
  - docs/
  - spec/
  - .github/

externals:
  Libs/LibStub:
    url: https://repos.curseforge.com/wow/libstub/trunk
    tag: latest
```

Packager: copies checkout → `.release/`, checks out externals,
replaces `@project-version@`, `@localization@`, strips `@debug@`,
generates changelog from git history, zips (+ nolib if enabled).

Key flags (`release.sh --help`):
`-S` split multi-flavor TOCs, `-s` nolib, `-d` skip upload,
`-g retail|classic|bcc|wrath|cata|mists` set game version,
`-p/-w/-a` override IDs, `-n "{package-name}-{project-version}"` naming.

Multi-flavor example:

```yaml
# .github/workflows/release.yml
- uses: BigWigsMods/packager@v2
  with:
    args: -S
```

generates `Addon.toc`, `Addon_Classic.toc`, `Addon_Vanilla.toc` from one source.

## 4. GitHub Actions release workflow

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: BigWigsMods/packager@v2
        env:
          CF_API_KEY: ${{ secrets.CF_API_KEY }}
          WOWI_API_TOKEN: ${{ secrets.WOWI_API_TOKEN }}
          WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}
          GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
```

Setup:
1. Create projects on each site, paste IDs in TOC.
2. Add secrets `CF_API_KEY` (CurseForge Author Dashboard → API Tokens),
   `WOWI_API_TOKEN` (WoWI File Management), `WAGO_API_TOKEN`
   (`addons.wago.io/account/apikeys`).
3. `git tag v0.1.0; git push --tags` → zip + uploads + GitHub Release.
4. `fetch-depth: 0` required for changelog; give `GITHUB_TOKEN` write perms.

Wago manual API (if not using packager):

```bash
curl -f -X POST \
  -F "metadata=$METADATASTRING" \
  -F "file=@.release/DSWowForever.zip" \
  -H "authorization: Bearer $WAGO_API_TOKEN" \
  -H "accept: application/json" \
  https://addons.wago.io/api/projects/<id>/version
```

## 5. Manual QA before tag

- [ ] `wowlua_ls check .` clean
- [ ] `busted` green
- [ ] Fresh `_classic_era_/Interface/AddOns` install, no other addons, `/reload`
- [ ] `11509` loads without “out of date” checked
- [ ] BugSack empty on login / reload / combat / logout
- [ ] Zip contains only runtime files (no `docs/`, `spec/`)
