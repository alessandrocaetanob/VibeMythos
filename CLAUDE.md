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
7. **Relative URIs in theme XAML resolve against the Playnite install root, not the theme folder.**
   `Playnite/Common/Xaml.cs` loads theme files with `XamlReader.Load(stream)` and **no
   `ParserContext`**, and `Themes.cs` assigns `ResourceDictionary.Source` only *afterwards* —
   too late to re-base objects already constructed during parsing. Consequences:
   - Use `{ThemeFile 'Images/x.png'}` for images. A bare `UriSource="Images/x.png"` silently
     resolves nowhere — the `WindowImageBackgroundBrush` and `WindowImageBackgroundBrush1`
     `ImageBrush`es were dead for this reason, and were removed in HYP-195.
   - `{ThemeFile}` **cannot** carry a font: it `File.Exists`-checks the relative path, and a
     `FontFamily` needs a `#Family Name` fragment that breaks the check. The fragment is
     mandatory — a path to a `.ttf` with no fragment silently yields Arial.
   - For fonts, use an **install-root-relative** path — verified on device, on a **portable**
     install: `Themes/Desktop/VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca/Typefaces/#Inter`.
     ⚠️ This resolves against the *application base directory*. On a standard install, themes
     fetched from the addon browser land in `%AppData%\Playnite\Themes\Desktop\` while the app
     base stays in the install dir, so the path misses and the chain degrades to system fonts.
     Always append fallbacks (`…/Typefaces/#Inter, Inter, Segoe UI`).
   - **WPF family matching is fuzzy**: a missing `Inter Tight` or `Inter Mod` silently resolves to
     an installed `Inter` rather than falling through the chain. Missing fonts never fail loudly,
     so verify by removing the bare-name entry and watching for an unmistakable fallback. A
     corollary: a bare `Inter` placed *after* `Inter Tight`/`Inter Mod` is dead weight, and every
     entry after it is unreachable on any machine with Inter installed.
   - Variable fonts **do** work — WPF exposes all named weight instances. Choose per family by the
     *reported* family name: `InterTight[wght].ttf` reports `Inter Tight`, but `InterVariable.ttf`
     reports `Inter Variable Text`, so Inter ships as statics. Note `[wght]` is both a PowerShell
     wildcard and an illegal URI character — `Copy-Item -LiteralPath` and rename.
   - **Never bind a path-bearing font token to `HtmlTextView.HtmlFontFamily`.** That control
     stringifies `FontFamily.ToString()` into a *quoted* CSS `font-family`
     (`Playnite/Controls/HtmlTextView.cs`), so the whole chain is read as one family name and
     matches nothing. It also renders via HtmlRenderer, which only sees system-installed fonts —
     bundled files are unreachable there. Use a single-name token (`HtmlDescriptionFontFamily`).
8. **Never name a theme asset directory `Fonts/`** — `Toolbox.exe pack` blacklists `^Fonts\\`
   (`Playnite.Toolbox/Themes.cs`, `PackageFileBlackListRegex`, alongside `.sln`, `.csproj`,
   `.csproj.user`, `.vs\`, `bin\`, `obj\`, `backup_`). Anything you put there works when deployed
   by hand and **silently vanishes from the `.pthm`** — this theme uses `source/Typefaces/` for
   exactly that reason. The blacklist is anchored at the start of the relative path, so any other
   name is safe. Confirm the list straight from the shipped binary:

   ```powershell
   $b=[IO.File]::ReadAllBytes('F:\Playnite\Toolbox.exe')
   [regex]::Matches([Text.Encoding]::Unicode.GetString($b),'\^[\w\\]+\\\\') | ForEach-Object Value
   ```

   Always verify a release by listing the packed archive, not just by deploying — a successful
   `pack` is **not** evidence that a file shipped:

   ```powershell
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $z=[IO.Compression.ZipFile]::OpenRead($pthm); $z.Entries.Count; $z.Dispose()
   ```
9. **Playnite identifies an addon by `Id` alone** — never by `Name` or `Author`. `Addons.cs` does
   `serviceClient.GetAddon(manifest.Id)` and updates on `package.Version > currentVersion`, with the
   update row rendering the *server's* name and no author. `ExtensionInstaller.InstallPackedFile`
   then calls `FileSystem.CreateDirectory(installDir, true)` — a **recursive wipe** — before
   extracting. Consequences:
   - This fork therefore carries **its own `Id`** (`VibeMythos_fb4d738f-…`), split from upstream in
     HYP-200. While it shared upstream's Id, bansakai's next release above our `Version` would have
     silently replaced the fork with upstream Mythos on the user's next update check.
   - The `Id` must stay in sync across four files: `source/theme.yaml`, `source/themeExtras.yaml`,
     `Manifest/Addon_Manifest.yaml`, `Manifest/Installer_Manifest.yaml` — plus the three font chains
     in `Constants.xaml`, which embed it as a path segment (rule 7).
   - It also keys ThemeModifier and ThemeExtras settings buckets, and Playnite's own
     `config.json` theme selection. Changing it again orphans all of them.
   - **The recursive wipe means anything a user drops inside the theme folder is destroyed on every
     install/update** — custom platform icons, sidebar icons, theme audio. The README warns about it;
     keep that warning if you touch those instructions.

## Repository layout

| Path | Purpose |
|---|---|
| `source/` | The theme itself (extracted from the upstream 2.0 `.pthm`, which is just a zip). This is what gets edited and packaged. |
| `source/theme.yaml` | Manifest: `Id`, `Version`, `ThemeApiVersion` (2.9.0 — must match Playnite's `DesktopApiVersion`; a major bump breaks loading). |
| `source/Constants.xaml` | Colors, brushes, sizes, and all ThemeModifier-editable toggles. 196 keyed resources. |
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

**Resource reference resolution** — the highest-value check in the repo. An unresolved `DynamicResource` never throws; WPF just leaves the property at its inherited value, so a typo'd or deleted key is invisible until someone notices the wrong colour months later. It found four of the six broken references repaired in HYP-195 (the other two were already known), and it is the *only* thing that can catch a case typo.

Run both blocks below together — the second reuses `Get-Keys`. Four details are load-bearing; changing any of them silently weakens the check:

- **Ordinal comparison.** WPF resource lookup is case-sensitive. A PowerShell `@{}` hashtable is **not**, so `$defined.ContainsKey('subtalBrush')` returns true when only `SubtalBrush` exists — which is exactly the bug that started HYP-195. Use an ordinal `HashSet`.
- **Four roots.** The theme, Playnite's default theme, Playnite's localization, and Playnite's global templates (which supply `False`, `ObjectToStringConverter`, `BooleanToVisibilityConverter` and ~1,100 others). Miss one and you get a flood of false positives.
- **Strip comments first.** A key named inside `<!-- -->` is not a usage.
- **Fail loudly on a bad path.** Without the count guards, a wrong `F:\Playnite` path yields an empty universe and the checks report "all clear" — indistinguishable from success, and the most dangerous possible output.

```powershell
$nsX='http://schemas.microsoft.com/winfx/2006/xaml'
function Get-Keys($p){
  try { $x=[xml](Get-Content $p -Raw); $nm=New-Object System.Xml.XmlNamespaceManager($x.NameTable); $nm.AddNamespace('x',$nsX)
        $x.SelectNodes('//*[@x:Key]',$nm) | ForEach-Object { $_.GetAttribute('Key',$nsX) } }
  catch { Write-Warning "unparseable, contributes no keys: $p"; @() }   # never fail silently
}
$defined = New-Object 'System.Collections.Generic.HashSet[string]'([StringComparer]::Ordinal)
foreach ($r in @('source','F:\Playnite\Themes\Desktop\Default','F:\Playnite\Localization','F:\Playnite\Templates\Themes')) {
  if (-not (Test-Path $r)) { throw "resource root missing: $r" }
  Get-ChildItem $r -Recurse -Filter *.xaml | ForEach-Object { Get-Keys $_.FullName | ForEach-Object { [void]$defined.Add($_) } }
}
if ($defined.Count -lt 1000) { throw "only $($defined.Count) keys loaded - expected ~1600; a root is wrong" }
$bad = 0
Get-ChildItem source -Recurse -Filter *.xaml | ForEach-Object {
  $f=$_; $t=[regex]::Replace((Get-Content $f.FullName -Raw),'(?s)<!--.*?-->','')
  # [^{},]+? permits spaces (e.g. "DuplicateHider_Epic Games_Icon") while excluding "{",
  # which skips nested extensions like {StaticResource {x:Type Button}} whose key is
  foreach ($m in [regex]::Matches($t,'\{(?:Dynamic|Static)Resource\s+(?:ResourceKey=)?([^{},]+?)\s*[},]')) {
    if (-not $defined.Contains($m.Groups[1].Value)) { $bad++; "UNRESOLVED $($f.Name): $($m.Groups[1].Value)" }
  }
}
"$bad unresolved"
```

**Before deleting any key, check it is not Playnite-global.** A key the theme never references may still be read by Playnite core for its own chrome — the inverted `WhiteColor`/`BlackColor` pair is the load-bearing example, and `MainColor` and `TooltipBackgroundBrush` are two the 3.0 plan wrongly listed as dead upstream palette.

⚠️ **Scope this to every theme file, not just `Constants.xaml`.** `Constants.xaml` redefines ~51 Playnite-global keys, but roughly **118 more** live in `Media.xaml`, `Views/SearchView.xaml`, `Views/TopPanel.xaml` and `DerivedStyles/` — window styles, item templates, tray icons, menu icons. All have zero theme references and are resolved by core by name, i.e. the exact profile a dead-key sweep deletes.

```powershell
$core = New-Object 'System.Collections.Generic.HashSet[string]'([StringComparer]::Ordinal)
Get-ChildItem 'F:\Playnite\Themes\Desktop\Default' -Recurse -Filter *.xaml | ForEach-Object { Get-Keys $_.FullName | ForEach-Object { [void]$core.Add($_) } }
if ($core.Count -lt 100) { throw "default theme unreadable ($($core.Count) keys) - check the path" }
Get-ChildItem source -Recurse -Filter *.xaml | ForEach-Object {
  $f=$_; Get-Keys $f.FullName | Where-Object { $core.Contains($_) } | ForEach-Object { "PLAYNITE-GLOBAL (retint, never delete)  $($f.Name): $_" }
}
```

Plugins also read theme keys they never appear to reference — `DuplicateHider_MaxNumberOfIcons` is one. Treat any `<Plugin>_*` key as an external API. Note the underscore heuristic is **not sufficient**: `SuccessStoryListGradient` and `SteamTealBrush` carry no underscore and were only confirmed safe by scanning the installed plugin DLLs. When in doubt, grep `F:\Playnite\Extensions` for the literal key name.

**Font chain / theme Id coupling** — the font tokens in `Constants.xaml` embed the deployed folder name, which Playnite derives from `theme.yaml`'s `Id`. Change the `Id` without updating the chains and the bundled fonts silently stop loading (see hard rule 7):

```powershell
$id = (Select-String source/theme.yaml -Pattern '^Id:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
Select-String source/Constants.xaml -Pattern 'Themes/Desktop/([^/]+)/Typefaces' -AllMatches |
  ForEach-Object { $_.Matches } | ForEach-Object {
    if ($_.Groups[1].Value -ne $id) { "MISMATCH: chain says '$($_.Groups[1].Value)', theme.yaml Id is '$id'" }
  }
```

**ThemeModifier key resolution** — every `thememodifier.yaml` entry must resolve to a key in `Constants.xaml` **or** `Localization/en_US.xaml`. The `Terminology` block deliberately targets localization strings (`LOCPlayGame`, `LOCMythos_More`, `LOCMythos_Edit`, `LOCMythos_SocialLinks`, `LOCMythos_AchievementsTitle`), so a validator that only checks `Constants.xaml` reports five false positives. Entries with no match anywhere render as section headers rather than controls — which is how the `"Accent Colors"`-style bare strings in that file work.

## Running and packaging

**Playnite here is a portable install at `F:\Playnite`** — *not* `%AppData%\Playnite`, which holds only stale remnants. Never infer installed plugins or theme state from `%AppData%`; it will be wrong.

| What | Where |
|---|---|
| Install root | `F:\Playnite` (`Toolbox.exe` lives here) |
| Deployed theme | `F:\Playnite\Themes\Desktop\VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca` |
| Installed plugins | `F:\Playnite\Extensions` (68 of them) |

```powershell
# Deploy. Copy-Item, never Move-Item — moving empties source/ in the repo.
$dest = "F:\Playnite\Themes\Desktop\VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca"
Copy-Item source\* $dest -Recurse -Force
```

Restart Playnite and select the theme in Settings → Appearance. **There is no hot reload.**

> A deploy once ran as a move and emptied 299 of the 305 files from `source/`. Nothing was lost — `git restore source/` recovered it — but verify `find source -type f | wc -l` still reports 314 after deploying.

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

**ThemeModifier is `playnite-thememodifier-plugin` (Lacro59, 3.0.2)** — the plugin that reads
`thememodifier.yaml`, and where this theme's settings surface.

A second, unrelated plugin with a confusingly similar name — DKG Theme Modifier
(`DKGThemeModifier_ee4ed2de-…`, David Griggs) — was also installed and has since been uninstalled.
It never touched Mythos, but it rewrites supported themes' Constants files **directly on disk**, so
if it ever reappears alongside a setting that will not stick, that is the first thing to check. Its
inert leftovers remain at `F:\Playnite\DKGThemeModifier` and
`F:\Playnite\ExtensionsData\ee4ed2de-…`.

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

- ~~**Global task progress is missing.**~~ **Shipped (HYP-155).** `PART_ProgressGlobal`, `PART_TextProgressText` and `PART_ButtonProgressCancel` now live in `Views/TopPanel.xaml`. Still open: the per-plugin indicator in Sidebar items, which uses `PART_ProgressStatus` (`CustomControls/SidebarItem.xaml`) → HYP-156.
- **7 Playnite-global `LOC*` keys are overridden** in `Localization/en_US.xaml` (of 38 total keys), leaking theme terminology outside the theme: `LOCAddonChangesRestart`, `LOCExitAppLabel`, `LOCNotesLabel`, `LOCOpenPlaynite`, `LOCPlayGame`, `LOCSettingsRestartNotification`, `LOCVersionLabel`. The other 31 are theme-owned `LOCMythos_*`. Additionally, every locale is missing **3** keys present in `en_US` (`LOCAddonChangesRestart`, `LOCSettingsRestartNotification`, `LOCMythos_NowPlaying` — the last never back-filled after the toast shipped in `b86b04e`, so the Now Playing string is untranslated in all 10 locales), and `de_DE.xaml` carries 9 stale keys that no longer exist in `en_US`. → HYP-166.
- **Plugin wiring is broadening but still shallow.** Ten plugin-injected controls are declared: `ExtraMetadataLoader_LogoLoaderControl(Grid)` ×2 each, `ExtraMetadataLoader_VideoLoaderControl`, `ThemeExtras_Banner`, `SuccessStory_Plugin{List,CompactList}`, `PlayniteAchievements_AchievementButton` ×2, `DuplicateHider_SourceSelector{,1,2}`. Real `PluginStatus`/`PluginSettings` markup-extension usage — **excluding matches inside XML comments**, which is a trap this file has fallen into twice — sits in `Views/DetailsViewGameOverview.xaml` (23), `Views/GridViewGameOverview.xaml` (17), `Views/MainWindow.xaml` (4), `Views/TopPanel.xaml` (3) and `DerivedStyles/GridViewItemTemplate.xaml` (**0** — it wires `DuplicateHider_SourceSelector` purely via the `ContentControl x:Name` convention; its only match is the word inside a comment). Achievements (HYP-157/158), source badges (HYP-160) and the ambient backdrop (HYP-163) have shipped; → HYP-159, HYP-161, HYP-165, HYP-167 remain, plus the Tier 1–3 plugins in the 3.0 plan.
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
