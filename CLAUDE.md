# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**VibeMythos** is a fork of [Mythos](https://github.com/bansakai/Mythos) (by bansakai) — a Fluent UI–inspired **desktop-mode theme for [Playnite](https://playnite.link)**. It is pure WPF/XAML resource dictionaries: **no code-behind, no compilation, no test suite**. The "build" is zipping a folder.

The fork exists to build on top of Mythos 2.0: deeper plugin integrations (achievements, music, source badges), progress/loading UI, Aniki-inspired visual patterns, and localization cleanup.

Repo artifacts (commits, code comments, docs) are written in **English**.

## Hard rules of Playnite desktop theme development

These are the constraints that are not discoverable from the code, and violating them produces silent failures rather than errors.

1. **You cannot add new XAML files.** Playnite's theme loader (`Playnite/Themes.cs`) only merges files whose relative path exists in the built-in default theme. New styles must go into an existing file. (The ThemeOptions plugin is the only sanctioned workaround — tracked in HYP-164.)
2. **Markup extensions:**
   - `{PluginSettings Plugin=<SourceName>, Path=<prop>, FallbackValue=..., Mode=...}` — reads a plugin's exposed settings/data. Uses the plugin **SourceName** (e.g. `SuccessStory`, `ThemeExtras`).
   - `{PluginStatus Plugin=<AddonId>, Status=Installed}` — visibility gate on plugin presence. Uses the **AddonId** (e.g. `playnite-successstory-plugin`, `felixkmh_Extras_Plugin`). Note these are *different identifier spaces* — mixing them up fails silently.
   - A binding targeting `Visibility` gets a `BooleanToVisibilityConverter` injected automatically — no explicit converter needed.
   - `{ThemeFile 'Images/x.png'}` for theme-owned assets; `{Settings <prop>}` for Playnite settings; `{Api Notifications.Count}` for API values.
3. **ThemeModifier keys must be consumed via `DynamicResource`, never `StaticResource`**, or live updates break.
4. **Plugin-injected controls**: declare `<ContentControl x:Name="<SourceName>_<ElementName>" />`; Playnite fills it if the plugin is installed, otherwise it renders nothing. To hide wrapper chrome, bind to the injected control's own `Visibility` (`{Binding ElementName=..., Path=Visibility}`) — Lacro59-style controls collapse themselves when they have no data.
5. **Localization** (`source/Localization/`):
   - `en_US.xaml` must exist or **no** localization loads at all.
   - Only `sys:String` entries survive loading; anything else is stripped.
   - Consume with `DynamicResource` (dictionaries merge after theme XAML).
   - Prefix theme-owned keys with `LOCMythos_`. Avoid overriding Playnite-global `LOC*` keys — they leak outside the theme.
6. **Template part names matter**: controls bind by `PART_*` name. Omitting a part silently drops that functionality — see *Known state* below.

## Repository layout

| Path | Purpose |
|---|---|
| `source/` | The theme itself (extracted from the upstream 2.0 `.pthm`, which is just a zip). This is what gets edited and packaged. |
| `source/theme.yaml` | Manifest: `Id`, `Version`, `ThemeApiVersion` (2.9.0 — must match Playnite's `DesktopApiVersion`; a major bump breaks loading). |
| `source/Constants.xaml` | Colors, brushes, sizes, and all ThemeModifier-editable toggles. 237 keyed resources. |
| `source/Common.xaml`, `source/Media.xaml` | Base styles / icon and image specs. |
| `source/Views/` | Library views and panels (`MainWindow`, `TopPanel`, `DetailsViewGameOverview`, `GridViewGameOverview`, `Sidebar`, …). |
| `source/DefaultControls/` | Restyles of built-in WPF controls. |
| `source/DerivedStyles/` | Styles for specific Playnite cases (PlayButton, GridViewItemTemplate, MainWindowStyle, …). |
| `source/CustomControls/` | Styles for Playnite custom controls (SidebarItem, TopPanelItem, SearchBox, …). |
| `source/Localization/` | One `ResourceDictionary` per locale (11 locales). |
| `source/thememodifier.yaml` | ThemeModifier manifest — exposes keys as user settings. |
| `source/themeExtras.yaml` | ThemeExtras manifest — banner paths, persistent paths. |
| `Manifest/` | Playnite addon-database manifests (`Addon_Manifest.yaml`, `Installer_Manifest.yaml` with release history). |
| `Resources/`, `Screenshots/` | README/store assets — **not** part of the packaged theme. |

Nearly all `.xaml` edits land in one of the four style directories; `Views/` holds the layout work.

## Validating changes

There is no compiler, so these checks are the only automated safety net. All are verified to run in this repo's PowerShell.

**XAML well-formedness** (every file must parse as XML):

```powershell
Get-ChildItem source -Recurse -Filter *.xaml | ForEach-Object {
  try { [xml](Get-Content $_.FullName -Raw) | Out-Null }
  catch { "FAIL $($_.FullName): $($_.Exception.Message)" }
}
```

**Localization key parity** — every locale's keys must be a subset of `en_US`:

```powershell
function Get-Keys($p) {
  $x = [xml](Get-Content $p -Raw)
  $nm = New-Object System.Xml.XmlNamespaceManager($x.NameTable)
  $nm.AddNamespace('x','http://schemas.microsoft.com/winfx/2006/xaml')
  $x.SelectNodes('//*[@x:Key]',$nm) | ForEach-Object { $_.GetAttribute('Key','http://schemas.microsoft.com/winfx/2006/xaml') }
}
$en = Get-Keys 'source/Localization/en_US.xaml'
Get-ChildItem source/Localization -Filter *.xaml | Where-Object Name -ne 'en_US.xaml' | ForEach-Object {
  $k = Get-Keys $_.FullName
  "{0,-11} keys={1,-3} missing={2,-3} extra={3}" -f $_.Name, $k.Count,
    (@($en | Where-Object {$k -notcontains $_}).Count), (@($k | Where-Object {$en -notcontains $_}).Count)
}
```

Use the namespace-aware `Get-Keys` above, **not** `grep 'x:Key='` — the grep count is inflated by commented-out blocks (46 lines vs 37 real keys in `en_US.xaml`).

**ThemeModifier key resolution** — every `thememodifier.yaml` entry must resolve to a key in `Constants.xaml` **or** `Localization/en_US.xaml`. The `Terminology` block deliberately targets localization strings (`LOCPlayGame`, `LOCMythos_More`, `LOCMythos_Edit`, `LOCMythos_SocialLinks`, `LOCMythos_AchievementsTitle`), so a validator that only checks `Constants.xaml` reports five false positives. Entries with no match anywhere render as section headers rather than controls — which is how the `"Accent Colors"`-style bare strings in that file work.

## Running and packaging

**Playnite here is a portable install at `F:\Playnite`** — *not* `%AppData%\Playnite`, which holds only stale remnants. Never infer installed plugins or theme state from `%AppData%`; it will be wrong.

| What | Where |
|---|---|
| Install root | `F:\Playnite` (`Toolbox.exe` lives here) |
| Deployed theme | `F:\Playnite\Themes\Desktop\Mythos_9f42c1a7-6d8e-4b3f-b0a2-7e9c5d3f18a4` |
| Installed plugins | `F:\Playnite\Extensions` (68 of them) |

```powershell
# Deploy. Copy-Item, never Move-Item — moving empties source/ in the repo.
$dest = "F:\Playnite\Themes\Desktop\Mythos_9f42c1a7-6d8e-4b3f-b0a2-7e9c5d3f18a4"
Copy-Item source\* $dest -Recurse -Force
```

Restart Playnite and select the theme in Settings → Appearance. **There is no hot reload.**

> A deploy once ran as a move and emptied 299 of the 305 files from `source/`. Nothing was lost — `git restore source/` recovered it — but verify `find source -type f | wc -l` still reports 305 after deploying.

Packaging, from `F:\Playnite`:

```powershell
.\Toolbox.exe pack <themeDir> <outDir>          # produces the .pthm
.\Toolbox.exe verify addon Manifest\Addon_Manifest.yaml
```

### Plugins actually installed here

Relevant to the integration work — confirmed present in `F:\Playnite\Extensions`:

`felixkmh_DuplicateHider_Plugin`, `felixkmh_Extras_Plugin` (ThemeExtras), `UniPlaySong`,
`PlayniteAchievements`, `playnite-howlongtobeat-plugin`, `ExtraMetadataLoader_705fdbca-…`.

One thing that contradicts the cheat sheet below: **SuccessStory is not installed** — this setup uses
**PlayniteAchievements** instead, so HYP-157/158 should target that naming scheme first.

**Two similarly-named ThemeModifiers are installed, and only one is ours.**
`playnite-thememodifier-plugin` (Lacro59, 3.0.2) is the plugin that reads `thememodifier.yaml`;
that is where this theme's settings surface. `DKGThemeModifier_ee4ed2de-…` (David Griggs, 2.8.3) is
an unrelated plugin that works from its own allowlist of supported themes and rewrites their
Constants files **directly on disk**. It carries no Mythos entry today, but if that ever changes it
would edit the deployed `Constants.xaml` underneath a debugging session.

Don't bump `source/theme.yaml` `Version` / `ThemeApiVersion` casually — `ThemeApiVersion` is gated against Playnite's `DesktopApiVersion` (major mismatch = the theme refuses to load).

## SonarQube

Analysis runs against **SonarQube Cloud**, org `alessandrocaetanob`, project key `alessandrocaetanob_VibeMythos`. Config lives in `sonar-project.properties`.

```powershell
sonar auth status                                        # verify the token / org
sonar analyze                                            # analyze the git change set
sonar analyze --base Master                              # analyze everything changed vs Master
sonar analyze --file source/Views/TopPanel.xaml          # analyze one file
sonar list issues -p alessandrocaetanob_VibeMythos
```

**`sonar-project.properties` is read by the CI-side scanner, not by the local `sonar` CLI** — the CLI does not resolve the project key from it, so pass `-p alessandrocaetanob_VibeMythos` explicitly (always required on `sonar list`, and needed on `sonar analyze` for server-side steps). Vortex/agentic analysis is not available for this organization; the "Vortex analysis skipped" notice on a local run is expected and harmless.

Scope note: there is no compiled language here, so Sonar's value is the **XML analyzer over `.xaml`** (registered via `sonar.xml.file.suffixes`), YAML rules over the manifests, and secrets scanning. Coverage metrics are excluded — no test framework can exist for a resource-dictionary-only theme, so leaving coverage in would permanently fail the quality gate.

## Workflow

**Linear** — project [VibeMythos](https://linear.app/hyperius/project/vibemythos-d8f8db975f6c), team **Hyperius** (`HYP`). One issue per work session; keep it updated as you go. Linear supplies the branch name per issue (`alessandrocaetanob/hyp-<n>-<slug>`) — use it, and push with `git push -u origin <branch>`. Default branch is `Master` (capital M).

**Upstream sync** — Mythos ships *all* default-theme style files, so any Playnite release that changes theme files may require a diff pass (track via [Playnite#1259](https://github.com/JosefNemec/Playnite/issues/1259)).

### Tooling worth reaching for

- **Microsoft Learn MCP** (`microsoft_docs_search` / `microsoft_code_sample_search`) — the best source for WPF/XAML specifics: storyboards, triggers, `VisualStateManager`, binding modes, render-transform performance.
- **Context7** — up-to-date docs for any library or tool; prefer it over web search for API/config questions.
- **Tavily** — plugin wikis and theme-dev material that isn't in official docs (most Playnite plugin documentation lives in GitHub wikis).
- **GitHub MCP** — read the reference themes and plugin sources listed below directly, rather than guessing at control names.
- **SonarQube MCP / `sonar-*` skills** — quality gate, issues, and analysis.
- **`frontend-design` skill** — invoke it when designing or reshaping visual surfaces (Details/Grid view layouts, badges, transitions, the ambient backdrop work) so changes read as intentional rather than templated.

## Known state and tracked debt

Verified against the current tree — useful context before touching these areas:

- **Global task progress is missing.** `PART_ProgressGlobal`, `PART_TextProgressText`, and `PART_ButtonProgressCancel` do not exist anywhere in `source/`, which is why users see no task progress bar. Only `PART_ProgressStatus` (in `CustomControls/SidebarItem.xaml`) is present. → HYP-155, HYP-156.
- **16 Playnite-global `LOC*` keys are overridden** in `Localization/en_US.xaml` (of 37 total keys), leaking theme terminology outside the theme. Additionally, every locale is missing 2 keys present in `en_US` (`LOCAddonChangesRestart`, `LOCSettingsRestartNotification`), and `de_DE.xaml` carries 9 stale keys that no longer exist in `en_US`. → HYP-166.
- **Plugin wiring is shallow.** Only six plugin-injected controls are currently declared: `ExtraMetadataLoader_LogoLoaderControl(Grid)` ×2 each, `ExtraMetadataLoader_VideoLoaderControl`, `ThemeExtras_Banner`, `SuccessStory_PluginList`, `SuccessStory_PluginCompactList`. `PluginStatus`/`PluginSettings` usage is concentrated in `Views/DetailsViewGameOverview.xaml` (14), `Views/GridViewGameOverview.xaml` (8), and `Views/TopPanel.xaml` (3). → HYP-157 through HYP-161.
- **No CI yet** — validation is manual via the commands above. → HYP-168.

## Plugin integration cheat sheet

| Plugin | SourceName | AddonId / GUID | Key surface |
|---|---|---|---|
| [SuccessStory](https://github.com/Lacro59/playnite-successstory-plugin/wiki/Addition-in-a-custom-theme) (Lacro59) | `SuccessStory` | `cebe6d32-8c46-4459-b993-5a5189d60788` | Controls `SuccessStory_Plugin{ViewItem,Button,Chart,List,CompactList,CompactUnlocked,CompactLocked,ProgressBar,UserStats}`; data `HasData, Is100Percent, Unlocked, Locked, Total, Percent, TotalGamerScore, Common/Rare/UltraRare, ListAchUnlockDateDesc`; toggles `EnableIntegration*`. Custom button wrapper: `PART_CustomScButton`. |
| [Playnite Achievements](https://github.com/justin-delano/PlayniteAchievements/wiki) (justin-delano) | `PlayniteAchievements` | see its `extension.yaml` | Modern controls `PlayniteAchievements_Achievement{Button,ProgressBar,CompactList,BarChart,PieChart,Stats,DataGrid,ViewItem,…}`; legacy SuccessStory-shaped bindings; theme-overridable toast via `PlayAch.Template.AchievementToast`. Ships a Theme Migration tool that rewrites installed theme files — **support both naming schemes**. |
| [UniPlaySong](https://github.com/aHuddini/UniPlaySong) (aHuddini) | `UniPlaySong` | — | Desktop-capable. Elements `UPS_MusicControl` (Tag="True" pauses music), `UPS_NowPlayingMiniPlayer(Compact)`, `UPS_MediaController{Overlay,Bar,Compact}`; paths `NowPlayingTitle/Artist/AlbumArtPath`, `ActiveMedia{IsPlaying,Progress,PositionText,…}`, `IsMusicChanged`; URI commands `playnite://uniplaysong/{play,pause,next,…}`. Theme can ship `audio/UPS_BackgroundAudio.mp3`. Ignores muted MediaElements (EML trailer coexistence). |
| [ThemeExtras](https://github.com/felixkmh/ThemeExtras-for-Playnite/wiki) (felixkmh) | `ThemeExtras` | `felixkmh_Extras_Plugin` | Controls `ThemeExtras_{User,Community,Critic}Rating`, `ThemeExtras_Settable{Favorite,UserScore,Hidden,CompletionStatus}`, `ThemeExtras_Banner`, `ThemeExtras_Links`; commands `Commands.{Back,Forward,SwitchMode,OpenPluginSettings,…}`; converter `UrlToAsyncIconConverter`; `themeExtras.yaml` supports `WebsiteIconsPath`, `BannersBySourceNamePath`, `Recommendations`, `PersistentPaths` (images inside need `CacheOption=OnLoad`). |
| [ThemeModifier](https://github.com/Lacro59/playnite-thememodifier-plugin/wiki/Integrate-editable-constants) (Lacro59) | `ThemeModifier` | `playnite-thememodifier-plugin` | `thememodifier.yaml` next to `theme.yaml`; types Boolean/String/Double/Int/Color/Brush/Visibility/Alignments; numeric ranges `Key(min,max): Label`. |
| [HowLongToBeat](https://github.com/Lacro59/playnite-howlongtobeat-plugin/wiki/Addition-in-a-custom-theme) (Lacro59) | `HowLongToBeat` | `e08cd51f-9c9a-4ee3-a094-fde03b55492f` | Controls `HowLongToBeat_Plugin{Button,ProgressBar,ViewItem}`; data `HasData`, `MainStoryFormat/MainExtraFormat/CompletionistFormat` (pre-formatted strings — enough to build a fully custom row). |
| [ExtraMetadataLoader](https://github.com/darklinkpower/PlayniteExtensionsCollection/wiki/Extra-Metadata-Loader-theme-controls) (darklinkpower) | `ExtraMetadataLoader` | `705fdbca-e1fc-4004-b839-1d040b8b4429` | Controls `..._LogoLoaderControl(_DisableOpacityAnimation)`, `..._VideoLoaderControl_{Controls,NoControls}_{Sound,NoSound}` (bind own buttons to `Content.VideoPlayCommand` / `Content.VideoMuteCommand`); settings `EnableVideoPlayer, EnableLogos, LogoMax{Width,Height}, Logo{Horizontal,Vertical}Alignment`; per-game `IsLogoAvailable, IsAnyVideoAvailable, IsVideoPlaying`. |
| [DuplicateHider](https://github.com/felixkmh/DuplicateHider) (felixkmh) | `DuplicateHider` | `felixkmh_DuplicateHider_Plugin` | Source-icon selectors `DuplicateHider_SourceSelector`(`0`–`9`); theme supplies icons via resource keys `DuplicateHider_<SourceName>_Icon` (BitmapImage), `DuplicateHider_MaxNumberOfIcons`, styles `DuplicateHider_Icon{ContentControl,StackPanel}Style`. The standard route for Steam/GOG/Epic badges. |
| AnikiHelper (Mike-Aniki) | — | — | **Fullscreen-only — do not use in this desktop theme.** Its patterns (A/B image crossfade via `PathA`/`PathB` + flip bool, stamp-retriggered storyboards) are portable and worth copying in pure XAML. |

Reference themes with public source: [Helium](https://github.com/darklinkpower/Helium), [Nova-X](https://github.com/darklinkpower/Nova-X), [Stardust](https://github.com/darklinkpower/Stardust) (darklinkpower — canonical plugin-wiring examples), [eMixedNite](https://github.com/eminaguil/eMixedNite), [Aniki ReMake](https://github.com/Mike-Aniki/Aniki-ReMake) (fullscreen, design reference).

Playnite theme docs: https://api.playnite.link/docs/tutorials/themes/introduction.html
