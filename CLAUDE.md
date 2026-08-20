# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**VibeMythos** is a fork of [Mythos](https://github.com/bansakai/Mythos) (by bansakai) — a Fluent UI–inspired **desktop-mode theme for [Playnite](https://playnite.link)**. It is pure WPF/XAML resource dictionaries: **no code-behind, no compilation, no test suite**. The "build" is zipping a folder.

The fork exists to build on top of Mythos 2.0: deeper plugin integrations (achievements, music, source badges), progress/loading UI, Aniki-inspired visual patterns, and localization cleanup.

Repo artifacts (commits, code comments, docs) are written in **English**.

**Explicit non-goal: there is no light theme, and there will not be one.** The theme inverts
Playnite's own palette keys — `Constants.xaml:158-159` defines `WhiteColor` as `#18181B` and
`BlackColor` as `#707275` — precisely so core-drawn chrome the theme never touches still comes out
dark. Undoing that is not a preset, it is a different theme. Every planned appearance pack (Slate,
Noir, Vibrant) is dark. Recorded here because it keeps getting re-derived at planning time.

## Hard rules of Playnite desktop theme development

These are the constraints that are not discoverable from the code, and violating them produces silent failures rather than errors.

1. **You can only claim file paths the default theme already merges — but 16 of those are still unclaimed.**
   `ThemeManager.ApplyTheme` (`Playnite/Themes.cs`) builds an `acceptableXamls` list by walking
   `app.Resources.MergedDictionaries` and keeping every entry whose `Source` starts with
   `Themes/Desktop/Default/`. It then loads `<themeDir>\<thatRelativePath>` for each, skipping any the
   theme does not ship. A file at a path outside that list is **never read** — no error, no log line.

   ⚠️ The gate is the **merged-dictionary list, not the directory listing**. A `.xaml` sitting in the
   Default theme folder but absent from `Playnite.DesktopApp/App.xaml` would still be ignored. For
   Playnite 10.56 the two happen to coincide exactly: App.xaml merges **84** dictionaries and the
   Default theme folder holds **84** `.xaml` files.

   This theme ships **68** of the 84 (79 files in `source/` minus the 11 `Localization/` dictionaries,
   which load through a different path — see rule 5). The remaining **16 are addable today**, verified
   2026-08-17 by diffing the folder against App.xaml's merge list:

   | Directory | Unclaimed paths |
   |---|---|
   | `DefaultControls/` | `Border.xaml`, `GridSplitter.xaml`, `Label.xaml`, `PasswordBox.xaml`, `Popup.xaml`, `TextBlock.xaml` |
   | `CustomControls/` | `ExpanderEx.xaml`, `ExtendedDataGrid.xaml`, `ExtendedListView.xaml`, `HotKeyBox.xaml`, `HtmlTextView.xaml`, `WindowBase.xaml` |
   | `DerivedStyles/` | `ImageHighlightButton.xaml`, `TextBlockGameScore.xaml`, `WindowBarButton.xaml` |
   | `Views/` | `LibraryListView.xaml` |

   So "shared code must go in `Common.xaml`" is a *style* choice, not a hard constraint — `Border.xaml`
   and `TextBlock.xaml` are legitimate homes for base styles. ThemeOptions (HYP-164) remains the only
   way to load a path that is **not** on the list at all.

   ✅ **Confirmed on device (HYP-212, 2026-08-19).** Both halves of the claim were exercised against
   Playnite 10.56 on this install, with a positive control to prove the method could detect a failure
   at all:

   | Run | `source/DefaultControls/` state | Result |
   |---|---|---|
   | Baseline | as shipped | starts clean, no theme errors |
   | Positive control | malformed `Button.xaml` (a path the theme **ships**) | `ThemeManager:Failed to load xaml …\Button.xaml` |
   | Test | malformed `Border.xaml` (a path the theme has **never shipped**) | `ThemeManager:Failed to load xaml …\Border.xaml` |
   | Precedence | valid `Border.xaml` with an implicit magenta `Style TargetType="Border"` | every Border in the UI renders magenta |

   The third run proves Playnite opens and parses a theme file at an unclaimed path. The fourth proves
   the theme's copy is merged **after** the default's and wins: the default's `Border.xaml` declares an
   implicit Border style setting only `SnapsToDevicePixels`, and the theme's copy replaced it wholesale.

   ⚠️ Two cautions that follow from the same evidence. An implicit `Style TargetType="Border"` has
   app-wide blast radius, which is exactly why the probe was so visible, so prefer `x:Key`ed styles in
   these files unless you genuinely mean to restyle every instance. And claiming a path means the theme
   now owns that file's parse risk under rule 10, so a new file is a new way to lose the whole theme.

   Note the cascade order is fixed by App.xaml, not by the theme: `ApplyTheme` re-merges
   default→theme per file in App.xaml's order, so a theme file's position in the lookup chain is not
   something the theme controls.

   Regenerate the unclaimed list with:

   ```powershell
   $def='F:\Playnite\Themes\Desktop\Default'
   $d=Get-ChildItem $def -Recurse -Filter *.xaml | ForEach-Object { $_.FullName.Substring($def.Length+1) }
   $s=Get-ChildItem source -Recurse -Filter *.xaml | ForEach-Object { $_.FullName.Substring((Resolve-Path source).Path.Length+1) }
   $d | Where-Object { $s -notcontains $_ }
   ```
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
   - `{ThemeFile}` **falls back to the default theme.** `ThemeFile.GetFilePath` tries the current
     theme's directory first, then the *default theme's* directory, and returns `null` only if both
     miss (`Playnite/Extensions/Markup/ThemeFile.cs`). So the theme never has to ship an asset the
     default theme already has — `{ThemeFile 'Images/Fallback.png'}` resolves even from Default. The
     flip side: a typo'd path that happens to exist in the default theme resolves to *Playnite's*
     asset rather than failing, so a wrong image is a likelier symptom than a missing one. On a total
     miss `ProvideValue` returns `null` and the property keeps its inherited value — silent, as ever.
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
   (`Playnite.Toolbox/Themes.cs`, `PackageFileBlackListRegex`). Anything you put there works when
   deployed by hand and **silently vanishes from the `.pthm`** — this theme uses `source/Typefaces/`
   for exactly that reason. The complete list, extracted from the shipped 10.56 binary on
   2026-08-17, is **8 patterns**: five anchored at the start of the relative path
   (`^Fonts\\`, `^\.vs\\`, `^bin\\`, `^obj\\`, `^backup_`) and three anchored at the end
   (`\.sln$`, `\.csproj$`, `\.csproj\.user$`). Any other directory name is safe.

   Confirm it straight from the binary. ⚠️ The obvious regex (`'\^[\w\\]+\\\\'`) finds only
   `^Fonts\\`, `^bin\\` and `^obj\\` — it silently misses the other five, which is worse than not
   checking. Use this instead:

   ```powershell
   $b=[IO.File]::ReadAllBytes('F:\Playnite\Toolbox.exe')
   $s=[Text.Encoding]::Unicode.GetString($b)
   [regex]::Matches($s,'\^[\w\\.]+\\{0,2}|\\\.[\w.\\]+\$') |
     ForEach-Object { $_.Value -replace '[^\x20-\x7E]' } | Sort-Object -Unique
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
10. **One XAML parse error costs the user the entire theme, not one file.** `ApplyTheme` pre-flights
    every acceptable path through `Xaml.FromFile` *before* merging anything. The first exception logs,
    sets `allLoaded = false`, **`break`s the loop**, and returns `AddonLoadError.Uknown` — Playnite
    then falls back to the Default theme wholesale. There is no partial application and no per-file
    degradation.

    This is the single strongest argument for landing CI (HYP-168) **before** the ~500-site token
    migration in 3.0-alpha, and the reason the well-formedness check is non-negotiable on every
    commit. Note well-formed-XML is necessary but not sufficient — `Xaml.FromFile` also throws on
    valid-XML-but-invalid-XAML (an unknown property, a bad type converter), which the `[xml]` cast
    will happily accept.

    ✅ **Verified on device (HYP-212, 2026-08-19)**, including the fallback: Playnite logged the two
    lines below to `F:\Playnite\playnite.log`, then started normally on the Default theme with all
    plugins loaded and **no error dialog**. The failure is silent to anyone not reading the log.

    ```
    ERROR|ThemeManager:Failed to load xaml <full path to the offending file>
    System.Windows.Markup.XamlParseException: ... em Playnite.ThemeManager.ApplyTheme(...) Themes.cs:linha 132
    ERROR|PlayniteApplication:Failed to load theme VibeMythos, Uknown.
    ```

    The first line names the exact file, which makes `playnite.log` the fastest way to identify a bad
    file after a deploy. Grep it with:

    ```powershell
    Select-String 'F:\Playnite\playnite.log' -Pattern 'Failed to load xaml|Failed to load theme' | Select-Object -Last 5
    ```
11. **A `Storyboard` inside a `Style` may not set `Storyboard.TargetName`.** WPF throws *"A Storyboard
    tree in a Style cannot specify a TargetName"* — and because of rule 10 that is a theme-wide
    failure, not a dead animation. A `Style` storyboard can only animate the styled element itself, so
    animate **by property path** (`Storyboard.TargetProperty="RenderTransform.X"`) and give the
    element its own unnamed `RenderTransform`. To drive several named children together, move the
    storyboard into the element's own `Triggers`/`ControlTemplate.Triggers`, where `TargetName` is
    legal. (Documented the hard way in UniPlaySong's theme-integration guide; it applies to every
    `Style`-hosted storyboard in this theme.)
12. **A `Style`-hosted storyboard cannot reach a resource in `Constants.xaml` — by either
    mechanism.** Define what it needs *locally, in the same file*. This cost the user a working
    theme on 2026-08-20 (HYP-244); the reasoning that led there was careful and still wrong, so
    the whole chain is worth keeping.

    Rule 10 says `ApplyTheme` pre-flights every file through `Xaml.FromFile` **before merging any
    of them**. The consequence nobody drew: during that pass a `StaticResource` resolves against
    Playnite's default theme *only*. The theme's own `Constants.xaml` has been parsed, but it is
    not in scope yet — and it does not matter that App.xaml merges it first (it does, position 1
    of 84). Merge order is a *runtime* fact; pre-flight happens before any of it.

    That alone is survivable, because an ordinary `Setter` value is **deferred** until the style
    is applied. That is why ~13 theme-only keys are consumed cross-file today and work fine
    (`PlayIconGeometry` in `PlayButton.xaml`, `CardBackgroundBrush` in `LibraryGridView.xaml`…).
    Those precedents are real, and they are exactly what makes the trap convincing.

    The trap is that a storyboard inside a `Style` or `ControlTemplate` **must be frozen** for the
    timing system, and freezing forces its `StaticResource` to resolve **eagerly, right there in
    pre-flight** rather than being deferred. So a `Duration` or easing key in `Constants.xaml` is
    unreachable from a storyboard:

    | | why not |
    |---|---|
    | `DynamicResource` | a Freezable holding a dynamic reference cannot be frozen (rule 3's inverse) |
    | `StaticResource` | resolves during pre-flight, when `Constants.xaml` is not in scope |

    ⚠️ The two fail *differently*, which is why testing one tells you nothing about the other. A
    `DynamicResource` here **parses and realizes fine** and breaks silently later, when the trigger
    fires — a dead animation, no log line. A `StaticResource` throws in pre-flight and takes the
    **entire theme** down under rule 10.

    So: duplicate the `Duration`/easing definitions into every file whose storyboards use them.
    `CustomControls/SidebarItem.xaml` had been doing this with `ElasticEase`/`BackEase` since
    before the fork — that is not a stylistic quirk to tidy away, it is the only mechanism that
    works. `Constants.xaml` keeps the canonical copy as documentation of intent.

    ✅ Catch it before deploying. `tools/check_xaml_wpf.ps1` phase 1 reproduces pre-flight exactly
    — Playnite's dictionaries merged, **zero** theme dictionaries — and reports the offending file
    and line. Verified both directions: 10 theme-killers against the broken tree, 0 against the
    fix. The harness originally missed this because it merged theme dictionaries as it went, which
    models the state *after* `ApplyTheme` succeeds, not pre-flight.

    ```powershell
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/check_xaml_wpf.ps1 -PreFlight
    ```

13. **`ApplyTheme` loads every file TWICE, and the second pass is not guarded.** Rule 12 covers
    the pre-flight at `Themes.cs:132`, whose throw is caught — `allLoaded = false`, fall back to
    the default theme. There is a **second** `Xaml.FromFile` at `Themes.cs:197`, in the pass that
    actually merges, and it is **outside that try/catch**. A throw there is an unhandled exception
    in `PlayniteApplication..ctor`: Playnite does not fall back, it **fails to start at all**.
    Shipped that way on 2026-08-20 (HYP-246) — the user could not open the app.

    The two passes see different resources, so a file can pass one and fail the other:

    | Pass | What is in scope | Failure |
    |---|---|---|
    | pre-flight `:132` | Playnite's defaults only; **no** theme file | theme falls back to Default |
    | merge `:197` | progressive — only what App.xaml merged **before** this file | **Playnite will not start** |

    The practical rule: **a theme file may only `StaticResource` something merged earlier than
    itself.** Positions are fixed by App.xaml, not by the theme. `Constants.xaml` is 1,
    `Common.xaml` 2, `DefaultControls/Border.xaml` 4, `Label.xaml` 16, `Views/*` 72–84.

    So `Common.xaml` **cannot** carry `BasedOn="{StaticResource {x:Type Border}}"` or
    `{x:Type Label}` — those implicit styles arrive at 4 and 16, long after it. A style at
    position 2 has to declare what it needs itself. The same reference is perfectly legal from
    `Views/FilterPanelView.xaml` (74) or `SearchView.xaml` (84), which is why the pattern looks
    safe elsewhere in the tree.

    ⚠️ Note this is the *opposite* shape to rule 12. There, merge order was irrelevant because
    pre-flight merges nothing; here it is the whole story. Both are real, and a change can trip
    either — check both.

    ✅ `tools/check_xaml_wpf.ps1` phase **1b** models this pass: it walks App.xaml's real order and
    loads each file with only its predecessors in scope, keeping Playnite's `Templates\Themes`
    and `Localization` pinned (they are already in the app and are not part of the theme merge
    list — clearing them invents failures on `LOCSaveLabel`, `False` and friends).

    Demonstrated on the tree that would not start: phase 1 reported **0**, phase 1b reported
    `FAIL Common.xaml (merged at position 2)`.


## Repository layout

| Path | Purpose |
|---|---|
| `source/` | The theme itself (extracted from the upstream 2.0 `.pthm`, which is just a zip). This is what gets edited and packaged. |
| `source/theme.yaml` | Manifest: `Id`, `Version`, `ThemeApiVersion` (2.9.0). See the gate note below the table. |
| `source/Constants.xaml` | Colors, brushes, sizes, and all ThemeModifier-editable toggles. **196 keyed resources over 449 lines** (2026-08-17, at `bba0dc2`). Count keys with the namespace-aware `Get-Keys` below, never by grepping. |
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

**The `ThemeApiVersion` gate is stricter than "major must match."** `ApplyTheme` rejects the theme when
`themeVersion.Major != apiVersion.Major` **or** `themeVersion > apiVersion`. Playnite 10.56 reports
`DesktopApiVersion = 2.9.0`, so `2.9.0` is simultaneously the required major *and* the ceiling —
declaring `2.10.0` or `3.0.0` makes the theme refuse to load on this build, while `2.8.0` is accepted.
Only raise it once a Playnite release actually raises `DesktopApiVersion`.

## Validating changes

There is no compiler, so these checks are the only automated safety net. All are verified to run in this repo's PowerShell.

**Start here: `tools/check_xaml_wpf.ps1`.** It is the closest thing this repo has to a
compiler, and the only check that covers hard rules 10 and 12 — it parses every file against
real WPF in a Playnite-shaped context.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/check_xaml_wpf.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/check_xaml_wpf.ps1 -PreFlight
```

Everything below, and `tools/validate_theme.py` in CI, proves the files are well-formed XML
and that their resource keys resolve. `Xaml.FromFile` also throws on an unknown property or
a bad type converter, and neither an `[xml]` cast nor the Python checker can see that.
Demonstrated rather than asserted: a `<Setter Property="NoSuchProperty">` in `Button.xaml`
passes both Python checks and fails this one at the exact file and line.

**It runs two phases, and they are not interchangeable.**

| Phase | Context | Catches |
|---|---|---|
| 1 · pre-flight | Playnite's dictionaries, **zero** theme dictionaries | anything that throws in `Xaml.FromFile` — one failure loses the **whole theme** |
| 2 · runtime | merge as you go, force every value to realize | deferred breakage pre-flight legitimately cannot see |

Phase 1 is the one that decides the exit code, and the one that matters. It exists because
the harness originally had only phase 2 and **passed a theme-killer straight through to a
deploy** (HYP-244): merging as it went put `Constants.xaml` in scope, which models the state
*after* `ApplyTheme` succeeds rather than the pre-flight it actually does first. `-PreFlight`
runs phase 1 alone, which is faster and enough for a quick check.

Three things make it work, and getting any of them wrong measures the harness instead of the
theme. The script handles all three; they are listed because the failure modes look like
theme bugs:

- **32-bit host.** Playnite is PE32/x86, so a 64-bit PowerShell cannot load its assemblies
  and every `Views/*.xaml` fails with `Failed to create a 'Type' from the text 'TopPanel'`.
  This one detail is the difference between **28** and **78** passing files. The script
  re-launches itself under `SysWOW64`.
- **Playnite's assemblies**, for the CLR types the Views reference by `clr-namespace`.
- **An `Application` object**, because `StaticResource` falls back to
  `Application.Current.Resources` — which is the *only* thing separating phase 1 from phase 2.

⚠️ A clean run is **1 expected failure**, not zero. `Media.xaml` always fails on a
`BitmapImage`: `{ThemeFile}` resolves against a *deployed* theme directory and `source/` is
not one (hard rule 7). Any *other* failure is real. Exit 0 clean, 1 otherwise, so it chains.

It cannot run in CI — Windows plus a Playnite install — so a green GitHub Actions run is
weaker evidence than a green local one. Run it before opening a PR that touches XAML, and
before every deploy.

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

Use the namespace-aware `Get-Keys` above, **not** `grep 'x:Key='`. A grep counts keys inside
`<!-- -->` blocks as real, and it trusts the `x:` prefix rather than the namespace it is bound to.
`en_US.xaml` used to demonstrate this (46 grepped lines vs 37 real keys); the hygiene bundle removed
those commented blocks, so today the two agree at **38 keys / 59 lines** — the discrepancy is latent,
not fixed, and returns the moment anyone comments a key out. `Get-Keys` is also what the
resource-resolution check below reuses, so there is no reason to keep a second counting method around.

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

**The mirror check: core paint keys the theme *fails* to redefine.** The sweep above only sees keys the
theme *does* define, so it is structurally blind to the opposite bug — a core `Color`/`Brush` the theme
never overrides, which then renders in Playnite's stock palette inside a near-black theme. That is
exactly how `WindowBackgourndBrush` left every plugin window navy until HYP-202. The default theme
declares **42** such keys, all in its own `Constants.xaml`. As of 2026-08-17 this theme redefines
**all 42** — the check passes with an empty list, and any new name in the output is a real gap:

```powershell
$nsX='http://schemas.microsoft.com/winfx/2006/xaml'
function Get-PaintKeys($p){
  try { $x=[xml](Get-Content $p -Raw); $nm=New-Object System.Xml.XmlNamespaceManager($x.NameTable); $nm.AddNamespace('x',$nsX)
        $x.SelectNodes('//*[@x:Key]',$nm) | Where-Object { $_.LocalName -match 'Color$|Brush$' } |
          ForEach-Object { $_.GetAttribute('Key',$nsX) } }
  catch { Write-Warning "unparseable: $p"; @() }
}
$corePaint = New-Object 'System.Collections.Generic.HashSet[string]'([StringComparer]::Ordinal)
Get-ChildItem 'F:\Playnite\Themes\Desktop\Default' -Recurse -Filter *.xaml |
  ForEach-Object { Get-PaintKeys $_.FullName | ForEach-Object { [void]$corePaint.Add($_) } }
if ($corePaint.Count -lt 40) { throw "only $($corePaint.Count) core paint keys - check the path" }
$theme = New-Object 'System.Collections.Generic.HashSet[string]'([StringComparer]::Ordinal)
Get-ChildItem source -Recurse -Filter *.xaml |
  ForEach-Object { Get-Keys $_.FullName | ForEach-Object { [void]$theme.Add($_) } }
$corePaint | Where-Object { -not $theme.Contains($_) } | Sort-Object |
  ForEach-Object { "NOT RETINTED (renders in Playnite's palette): $_" }
```

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

**Playnite here is a portable install at `F:\Playnite`.** Treat that as the source of truth — but
**check `%AppData%` for shadows before concluding anything, then ignore it.** `%AppData%` is not merely
stale: `ThemeManager.GetAvailableThemes` enumerates the user-data path *and* the program path and
deduplicates by `Id` with **user data winning**. So a stray `.pthm` double-click plants a copy under
`%AppData%\Playnite\Themes\Desktop\` that silently outranks every `Copy-Item` deploy — you would edit
the repo, deploy, restart, and see no change at all. The same user-data-first rule applies to
extensions.

Verified 2026-08-17: `%AppData%\Playnite\Themes\Desktop` **does not exist** (no shadow), and
`%AppData%\Playnite\Extensions` holds exactly one extension, `SunshinePlaynite`. So the honest
extension total is **68 in the install dir + 1 in `%AppData%` = 69 loaded**.

```powershell
# Run this first whenever a deployed change fails to appear.
$s = "$env:AppData\Playnite\Themes\Desktop\VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca"
if (Test-Path $s) { "SHADOW WINS OVER YOUR DEPLOY: $s" } else { "no shadow - install dir is authoritative" }
```

| What | Where |
|---|---|
| Install root | `F:\Playnite` (`Toolbox.exe` lives here) |
| Deployed theme | `F:\Playnite\Themes\Desktop\VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca` |
| Installed plugins | `F:\Playnite\Extensions` (68) + `%AppData%\Playnite\Extensions` (1) = **69 loaded** |

```powershell
# Deploy. Copy-Item, never Move-Item — moving empties source/ in the repo.
$dest = "F:\Playnite\Themes\Desktop\VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca"
Copy-Item source\* $dest -Recurse -Force
```

Restart Playnite and select the theme in Settings → Appearance. **There is no hot reload.**

### Scripting a Playnite run (verified in HYP-212)

Driving Playnite from a script to check a deploy is workable, but two behaviours will silently
invalidate a run if you do not handle them.

**`F:\Playnite\safestart.flag` poisons the next launch.** Playnite writes this zero-byte marker at
startup and clears it on a clean exit. Force-killing the process leaves it behind, and the *next*
launch then shows a modal `Startup Error` dialog ("Playnite closed unexpectedly while starting …
start in safe mode?"), which blocks startup and disables every add-on. A run that hits it measures
the prompt, not the theme. Delete the flag before every scripted launch:

```powershell
Remove-Item 'F:\Playnite\safestart.flag' -Force -ErrorAction SilentlyContinue
```

The same applies when you are done: clear it after the last force-kill so the user's next manual
launch is not met with the safe-mode prompt.

**This install has `StartMinimized: True` in `config.json`,** so a scripted launch never shows the
main window and any screenshot catches the splash or a progress dialog instead. Launching the exe a
second time activates the running instance and brings the real window up, which avoids editing the
user's config. Capture the window itself with `PrintWindow` (flag `2`, `PW_RENDERFULLCONTENT`) rather
than grabbing the screen, so an unrelated foreground app cannot end up in the shot. Note the capture
has to run under Windows PowerShell 5.1 (`powershell.exe`), because `pwsh` 7 has no GDI
`System.Drawing`. Pick the largest visible window across *all* `Playnite*` processes.

**Playnite resolves its database path against the current working directory.** Launching the exe
from a shell sitting in the repo makes Playnite build a fresh ~50MB `library/` there and re-import
every store plugin into it, instead of opening `F:\Playnite\library`. The real library is not touched
and the theme still loads normally, so this is easy to miss until `git status` shows the folder.
`library/` is gitignored for that reason. Launch with the working directory set to `F:\Playnite` to
exercise the actual library:

```powershell
Start-Process 'F:\Playnite\Playnite.DesktopApp.exe' -WorkingDirectory 'F:\Playnite'
```

Budget roughly **3 minutes per run** on this machine: about 5s to `Application started`, then two
minutes of library import and update checks before the UI is quiet.

> A deploy once ran as a move and emptied 299 of the 305 files from `source/`. Nothing was lost — `git restore source/` recovered it — but verify the file count after deploying. At `bba0dc2` it is **311** files (79 of them `.xaml`); re-read it from the tree rather than trusting this number, since it moves with every asset change:
>
> ```powershell
> (Get-ChildItem source -Recurse -File).Count
> ```

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

**ThemeOptions is also already installed** (`ThemeOptions_904cbf3b-573f-48f8-9642-0a09d05c64ef`,
version 0.32), which HYP-164 is written as though it were not. Its settings are empty
(`SelectedPresets` and `UserSettings` are both `{}` in
`F:\Playnite\ExtensionsData\904cbf3b-…\config.json`) and this theme ships no ThemeOptions manifest or
directory, so it currently loads nothing for us and can be trialled without a new install. Worth
knowing when reading a result that might otherwise be credited to it, which is why HYP-212 ruled it
out before trusting its own.

A second, unrelated plugin with a confusingly similar name — DKG Theme Modifier
(`DKGThemeModifier_ee4ed2de-…`, David Griggs) — was also installed and has since been uninstalled.
It never touched Mythos, but it rewrites supported themes' Constants files **directly on disk**, so
if it ever reappears alongside a setting that will not stick, that is the first thing to check. Its
inert leftovers remain at `F:\Playnite\DKGThemeModifier` and
`F:\Playnite\ExtensionsData\ee4ed2de-…`.

Don't bump `source/theme.yaml` `Version` / `ThemeApiVersion` casually — see the `ThemeApiVersion` gate note under *Repository layout*. `Version` is what the updater compares, so it must rise for a release to reach existing installs; `ThemeApiVersion` must **not** rise until Playnite's `DesktopApiVersion` does.

## SonarQube

Analysis runs against **SonarQube Cloud**, org `alessandrocaetanob`, project key `alessandrocaetanob_VibeMythos`. Config lives in `sonar-project.properties`.

```powershell
sonar auth status                                        # verify the token / org
sonar analyze                                            # analyze the git change set
sonar analyze --base master                              # analyze everything changed vs master
sonar analyze --file source/Views/TopPanel.xaml          # analyze one file
sonar list issues -p alessandrocaetanob_VibeMythos
```

**`sonar-project.properties` is read by the CI-side scanner, not by the local `sonar` CLI** — the CLI does not resolve the project key from it, so pass `-p alessandrocaetanob_VibeMythos` explicitly (always required on `sonar list`, and needed on `sonar analyze` for server-side steps). Vortex/agentic analysis is not available for this organization; the "Vortex analysis skipped" notice on a local run is expected and harmless.

Scope note: there is no compiled language here, so Sonar's value is the **XML analyzer over `.xaml`** (registered via `sonar.xml.file.suffixes`), YAML rules over the manifests, and secrets scanning. Coverage metrics are excluded — no test framework can exist for a resource-dictionary-only theme, so leaving coverage in would permanently fail the quality gate.

## Workflow

**Linear** — project [VibeMythos](https://linear.app/hyperius/project/vibemythos-d8f8db975f6c), team **Hyperius** (`HYP`). One issue per work session; keep it updated as you go. Linear supplies the branch name per issue (`alessandrocaetanob/hyp-<n>-<slug>`) — use it, and push with `git push -u origin <branch>`. Default branch is **`master`**, lowercase — renamed from `Master` in HYP-239 on 2026-08-17.

> ⚠️ If you ever need to rename it back, or rename any branch by case alone: `git branch -m Master master` **fails on NTFS** with "a branch named 'master' already exists", because the loose ref file collides case-insensitively. Go through a temp name (`git branch -m Master tmp && git branch -m tmp master`). The GitHub API read is also cached — `gh api repos/... --jq .default_branch` can report the *old* name right after a successful rename, so confirm with `--cache 0` or `git ls-remote --heads origin`.

**Upstream sync** — Mythos ships *all* default-theme style files, so any Playnite release that changes theme files may require a diff pass (track via [Playnite#1259](https://github.com/JosefNemec/Playnite/issues/1259)).

**The baseline is pinned at Playnite 10.56.0** (HYP-213), in `tools/baseline/` — names only,
no Playnite markup: 84 default-theme file paths, 177 default keys, 1,177 template and
localization keys, 42 paint keys, and the `PART_*` names per file. `tools/check_baseline.py`
diffs `source/` against it on every PR and fails on a dropped `PART_*` (the HYP-203/204
class), a core `Color`/`Brush` the theme never redefines (HYP-202), or a `.xaml` at a path
the default theme does not have (hard rule 1).

Two things follow that are easy to get wrong:

- **It compares against the fixture, never against the Playnite on your disk.** CI has no
  install — that is what lets it run on a Linux runner. A Playnite release that adds a file
  or a key stays invisible until somebody regenerates and reads the diff:

  ```powershell
  python tools/refresh_baseline.py --playnite "F:\Playnite"
  ```

- **The key manifest is also what makes `validate_theme.py` trustworthy.** It used to accept
  any key starting with `LOC` or `Glyph`, so a typo in one was indistinguishable from a real
  Playnite string. Those prefixes are gone; the plugin prefixes stay, because CLAUDE.md
  treats `<Plugin>_*` as an external API and no install can enumerate it. The residue is 21
  hand-listed names from `GlobalResources.xaml`, which is compiled into
  `Playnite.DesktopApp.exe` as `globalresources.baml` and cannot be harvested from disk.

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
- **7 Playnite-global `LOC*` keys are overridden** in `Localization/en_US.xaml` (of 38 total keys), leaking theme terminology outside the theme: `LOCAddonChangesRestart`, `LOCExitAppLabel`, `LOCNotesLabel`, `LOCOpenPlaynite`, `LOCPlayGame`, `LOCSettingsRestartNotification`, `LOCVersionLabel`. The other 31 are theme-owned `LOCMythos_*`. Additionally, every locale is missing **3** keys present in `en_US` (`LOCAddonChangesRestart`, `LOCSettingsRestartNotification`, `LOCMythos_NowPlaying` — the last never back-filled after the toast shipped in `b86b04e`, so the Now Playing string is untranslated in all 10 locales), . `de_DE.xaml`'s 9 stale keys are **gone** — re-verified 2026-08-17, all 10 locales now sit at exactly 35 keys with 0 extras, so the only remaining parity work is back-filling those 3. → HYP-166.
- **Plugin wiring is broadening but still shallow.** Ten plugin-injected controls are declared: `ExtraMetadataLoader_LogoLoaderControl(Grid)` ×2 each, `ExtraMetadataLoader_VideoLoaderControl`, `ThemeExtras_Banner`, `SuccessStory_Plugin{List,CompactList}`, `PlayniteAchievements_AchievementButton` ×2, `DuplicateHider_SourceSelector{,1,2}`. Real `PluginStatus`/`PluginSettings` markup-extension usage — **excluding matches inside XML comments**, which is a trap this file has fallen into twice — sits in `Views/DetailsViewGameOverview.xaml` (23), `Views/GridViewGameOverview.xaml` (17), `Views/MainWindow.xaml` (4), `Views/TopPanel.xaml` (3) and `DerivedStyles/GridViewItemTemplate.xaml` (**0** — it wires `DuplicateHider_SourceSelector` purely via the `ContentControl x:Name` convention; its only match is the word inside a comment). Achievements (HYP-157/158), source badges (HYP-160) and the ambient backdrop (HYP-163) have shipped; → HYP-159, HYP-161, HYP-165, HYP-167 remain, plus the Tier 1–3 plugins in the 3.0 plan.
- ~~**No CI yet.**~~ **Shipped (HYP-168).** `.github/workflows/validate.yml` runs the static checks, the theme-Id/font-chain coupling and manifest YAML parsing on every PR. HYP-213 added the pinned default-theme baseline diff on top. Not covered by CI and still manual: the real WPF parse, which needs a Playnite install.

## Plugin integration cheat sheet

| Plugin | SourceName | AddonId / GUID | Key surface |
|---|---|---|---|
| [SuccessStory](https://github.com/Lacro59/playnite-successstory-plugin/wiki/Addition-in-a-custom-theme) (Lacro59) | `SuccessStory` | `cebe6d32-8c46-4459-b993-5a5189d60788` | Controls `SuccessStory_Plugin{ViewItem,Button,Chart,List,CompactList,CompactUnlocked,CompactLocked,ProgressBar,UserStats}`; data `HasData, Is100Percent, Unlocked, Locked, Total, Percent, TotalGamerScore, Common/Rare/UltraRare, ListAchUnlockDateDesc`; toggles `EnableIntegration*`. Custom button wrapper: `PART_CustomScButton`. |
| [Playnite Achievements](https://github.com/justin-delano/PlayniteAchievements/wiki) (justin-delano) | `PlayniteAchievements` | see its `extension.yaml` | Modern controls `PlayniteAchievements_Achievement{Button,ProgressBar,CompactList,BarChart,PieChart,Stats,DataGrid,ViewItem,…}`; legacy SuccessStory-shaped bindings; theme-overridable toast via `PlayAch.Template.AchievementToast`. Ships a Theme Migration tool that rewrites installed theme files — **support both naming schemes**. |
| [UniPlaySong](https://github.com/aHuddini/UniPlaySong) (aHuddini) — [theme guide](https://github.com/aHuddini/UniPlaySong/blob/main/docs/dev_docs/THEME_INTEGRATION_GUIDE.md) | `UniPlaySong` | `UniPlaySong.a1b2c3d4-e5f6-7890-abcd-ef1234567890` | **Element prefix is `UPS_`, not `UniPlaySong_`.** Explicitly Desktop **and** Fullscreen. Elements: `UPS_MusicControl` (`Tag="True"` fades music out, `"False"` back in — only ever those two values, one instance), `UPS_MusicControl_PauseGamePlayDefault` (swaps game music for the user's default instead of silence; multiple instances OR together), `UPS_NowPlayingMiniPlayer{,Compact}` (display-only), `UPS_MediaController{Overlay,Bar,Compact}` (display **+** transport, self-styled, empty-tag), `UPS_SpectrumVisualizer`. Settings paths are **flat, never dotted** — `ActiveMediaIsPlaying`, not `ActiveMedia.IsPlaying`: `NowPlaying{Title,Artist,AlbumArtPath,Album,Genre,Duration}` (Album and Genre Spotify-only; Duration also fills for UPS game music when the file carries it), `ActiveMedia{IsPlaying,IsMuted,Progress,PositionText,DurationText,Volume,SourceName,SourceKind,HasMedia,CanNext,CanPrevious}` (Progress and Volume are 0–100), `IsMusicChanged` (pulses true→false for 750 ms per track change), plus two-way settings `EnableMusic`, `EnableDefaultMusic`, `RadioModeEnabled`, `SwitchRadioMode`, `RadioPlaysThroughGames`, `CalmDownModeEnabled`, `PlayOnlyOnGameSelect`. URIs: `playnite://uniplaysong/{play,pause,playpausetoggle,skip\|next,previous,togglemute,restart,stop,volume/0-100}`. Theme audio: `audio/UPS_BackgroundAudio.{mp3,ogg,wav,flac}` and per-rarity `audio/Achievements/{common,uncommon,rare,ultrarare,hidden,capstone}.wav`. Ignores muted/zero-volume `MediaElement`s, which is what makes EML trailer coexistence automatic — the audible-video auto-pause is gated by persisted `PauseOnThemeVideo` (default on), and the `UPS_MusicControl` Tag path has its own kill switch, `PauseOnThemeOverlay` (default on). The two OR into one pause decision (`VideoIsPlaying \|\| ThemeOverlayActive`), so theme-side trailer ducking via the Tag duplicates the plugin's own monitor under defaults and overrides the user's opt-out when it is off — measured in HYP-159, which ships zero coexistence wiring for exactly that reason. Coexists with PlayniteSound's `Sounds_MusicControl`. |
| [ThemeExtras](https://github.com/felixkmh/ThemeExtras-for-Playnite/wiki) (felixkmh) | `ThemeExtras` | `felixkmh_Extras_Plugin` | Controls `ThemeExtras_{User,Community,Critic}Rating`, `ThemeExtras_Settable{Favorite,UserScore,Hidden,CompletionStatus}`, `ThemeExtras_Banner`, `ThemeExtras_Links`; commands `Commands.{Back,Forward,SwitchMode,OpenPluginSettings,…}`; converter `UrlToAsyncIconConverter`; `themeExtras.yaml` supports `WebsiteIconsPath`, `BannersBySourceNamePath`, `Recommendations`, `PersistentPaths` (images inside need `CacheOption=OnLoad`). |
| [ThemeModifier](https://github.com/Lacro59/playnite-thememodifier-plugin/wiki/Integrate-editable-constants) (Lacro59) | `ThemeModifier` | `playnite-thememodifier-plugin` | `thememodifier.yaml` next to `theme.yaml`; types Boolean/String/Double/Int/Color/Brush/Visibility/Alignments; numeric ranges `Key(min,max): Label`. |
| [HowLongToBeat](https://github.com/Lacro59/playnite-howlongtobeat-plugin/wiki/Addition-in-a-custom-theme) (Lacro59) | `HowLongToBeat` | `e08cd51f-9c9a-4ee3-a094-fde03b55492f` | Controls `HowLongToBeat_Plugin{Button,ProgressBar,ViewItem}`; data `HasData`, `MainStoryFormat/MainExtraFormat/CompletionistFormat` (pre-formatted strings — enough to build a fully custom row). |
| [ExtraMetadataLoader](https://github.com/darklinkpower/PlayniteExtensionsCollection/wiki/Extra-Metadata-Loader-theme-controls) (darklinkpower) | `ExtraMetadataLoader` | `705fdbca-e1fc-4004-b839-1d040b8b4429` | Controls `..._LogoLoaderControl(_DisableOpacityAnimation)`, `..._VideoLoaderControl_{Controls,NoControls}_{Sound,NoSound}` (bind own buttons to `Content.VideoPlayCommand` / `Content.VideoMuteCommand`); settings `EnableVideoPlayer, EnableLogos, LogoMax{Width,Height}, Logo{Horizontal,Vertical}Alignment`; per-game `IsLogoAvailable, IsAnyVideoAvailable, IsVideoPlaying`. |
| [DuplicateHider](https://github.com/felixkmh/DuplicateHider) (felixkmh) | `DuplicateHider` | `felixkmh_DuplicateHider_Plugin` | Source-icon selectors `DuplicateHider_SourceSelector`(`0`–`9`); theme supplies icons via resource keys `DuplicateHider_<SourceName>_Icon` (BitmapImage), `DuplicateHider_MaxNumberOfIcons`, styles `DuplicateHider_Icon{ContentControl,StackPanel}Style`. The standard route for Steam/GOG/Epic badges. |
| AnikiHelper (Mike-Aniki) | — | — | **Fullscreen-only — do not use in this desktop theme.** Its patterns (A/B image crossfade via `PathA`/`PathB` + flip bool, stamp-retriggered storyboards) are portable and worth copying in pure XAML. |

> ⚠️ **On verifying plugin surfaces: do not conclude "it doesn't exist" from a string scan of a DLL.**
> A 2026-08-17 consolidation audit scanned `UniPlaySong.dll` and reported that the `UPS_MediaController*`
> controls and the whole `playnite://uniplaysong/…` command family were fiction, and HYP-206 was filed
> to delete them from this table. Re-verification against the plugin's own repository found **all of
> them real and documented** — the row above is now *expanded*, not cut. Two ways the scan misled:
> .NET string *literals* live in the UTF-16 `#US` heap while type and member names live in the UTF-8
> metadata heap, so a single-encoding scan sees half the picture; and the URI handler switches on path
> segments, so `play` and `pause` exist as short literals while the full URI string never appears
> anywhere in the binary. Read the plugin's docs or source. The only part of that audit finding that
> survived is the genuine (and minor) point that settings paths are flat rather than dotted.

Reference themes with public source: [Helium](https://github.com/darklinkpower/Helium), [Nova-X](https://github.com/darklinkpower/Nova-X), [Stardust](https://github.com/darklinkpower/Stardust) (darklinkpower — canonical plugin-wiring examples), [eMixedNite](https://github.com/eminaguil/eMixedNite), [Aniki ReMake](https://github.com/Mike-Aniki/Aniki-ReMake) (fullscreen, design reference).

Playnite theme docs: https://api.playnite.link/docs/tutorials/themes/introduction.html
