# VibeMythos 3.0 — Premium Desktop Library

Date: 2026-08-10 · corrected 2026-08-17 (HYP-206)
Status: proposed plan
Baseline: Mythos 2.0 fork, Playnite 10.56.0.23531, `ThemeApiVersion 2.9.0` (verified current — no bump needed)

> **Read this first.** The body below was written against the 2026-08-10 tree. HYP-206 re-verified it
> against `bba0dc2` and the installed Playnite 10.56, and corrected it in place — every correction is
> marked **✅ Corrected (HYP-206)**. Two items were *unsafe as written* and would have broken the theme
> if executed literally (C2's video-hack removal, B's "keep the Id"), and several were already shipped.
>
> **Milestones, not this document, are the source of truth for what is left.** The plan predates the
> Linear milestone structure; work is tracked in *v2.1 Test Release*, *3.0-alpha Foundation*,
> *3.0-beta Cinema*, *3.0 Release* and *3.1+ Beyond*. Where the two disagree, believe Linear.
>
> **Re-verify line numbers before acting on any individual item.** They have already drifted twice —
> `FlyOutEase` alone has been cited at `:396`, corrected to `:360`, and is actually at `:389`.

VibeMythos 3.0 is the release where the fork stops being "Mythos plus fixes" and becomes its
own theme: a design system instead of inherited constants, a motion language instead of
ad-hoc storyboards, and a details view that reads like a store page for *your* library.

**The pitch:** Playnite as a premium desktop game library — cinematic, calm, and alive.

- **Cinematic** — artwork is the material. Glass surfaces float over ambient art; every
  artwork change crossfades; the details view is a hero page, not a form.
- **Calm** — one type scale, one radius scale, one hover rule, one motion vocabulary.
  Premium is mostly the absence of inconsistency.
- **Alive** — music, play sessions, news, screenshots, friends, deals-with-your-time data
  (HLTB), rendered in *our* visual language by binding raw plugin data, never the plugins'
  default chrome.
- **Fast** — smooth scrolling on 1,000+ game libraries. Jank is the opposite of premium.

---

## Where 2.x actually stands (audit, 2026-08-10)

Full inventory was taken from the 2026-08-10 tree (79 XAML files, ~11.6k lines). At `bba0dc2` that is
**79 `.xaml` files / 11,768 lines**, inside **311** files total in `source/`. What it found shapes
every workstream below.

**Strengths to build on**

- A genuinely coherent near-black neutral ramp (`#0B0C0E → #18181B → #242427 → #323236`)
  plus a systematic glass/overlay layer (`ContentBrushOverlay` family) — the theme's
  defining material.
- Rich animation culture: 41 `BeginStoryboard`s, transform-driven, almost no bitmap
  effects (a single cheap `DropShadowEffect`; blur deliberately delegated to Playnite's
  own background handling — `Library.xaml:34`).
- The 2.x integration groundwork is done: global progress bar, Playnite Achievements,
  DuplicateHider badges, ambient backdrop, top-panel plugin fixes, Now Playing toast.

**Debt that blocks "premium"**

| Debt | Evidence |
| --- | --- |
| ~~Fonts are not shipped~~ **(fixed — HYP-194)** | `FontFamily`/`TightFont`/`MonospaceFontFamily` were bare system lookups and no font directory existed. Worse than a clean fallback: WPF family matching is fuzzy, so on the dev machine (where `Inter` is installed but `Inter Tight` and `Inter Mod` are not) **both silently resolved to `Inter`**. Measured: `FontFamily("Inter Mod, Consolas").FamilyNames` → `'Inter'`. Now shipped in `source/Typefaces/`. |
| No radius discipline | 17 radius tokens (two of them duplicates at 22: `ControlCornerRadiusLarger`, `GridCornerDetailsPanel`) **plus 48 literal `CornerRadius` values** in attribute form (72 counting `Setter`-form). Visible seam: `Sidebar.xaml:36` fill at radius 15 under a stroke at 16 (`:107`). |
| No spacing system | 110 distinct literal `Margin` values in attribute form (135 counting `Setter`-form); `Padding="0,11,0,11"` ×34; six `Margin="0,0,0,-1"` nudges compensating for the missing scale. |
| No motion tokens | Hover gesture alone: 7 distinct durations and 4 explicit easing types, with 36 of 58 hover animations carrying no explicit easing at all (implicit Linear). Theme-wide: 12 durations, 6 easing types. All literals. |
| Hover chaos | ~133 `Setter`s inside `IsMouseOver` triggers, resolving to **27 distinct brush tokens** (33 counting hardcoded literal colours). ✅ **Corrected (HYP-206):** `HoverBrush` (`#E7E9EA`, a *foreground*) is painted as a background/fill at **3 sites, not one** — `Menu.xaml:45` (`Background`) and `Thumb.xaml:51,:54` (`Fill`). Its ~20 other uses are all `Foreground`/`CaretBrush`, which are legitimate. `HoverBrush` is itself a **Playnite-global key: retint it, never rename it.** |
| Type scale half-adopted | 31 literal `FontSize` (13/15/19 aren't even in the scale) vs 39 tokenized. `FontSizeLarger`/`FontSizeLargest` are used but not defined *by this theme* — they resolve only because Playnite's default theme defines them (20/29) and merges first. Not a break, but the theme doesn't own its own display size, including on the game title (`DetailsViewGameOverview.xaml:735`). |
| Silent breakage | Two real ones: `ComboBox.xaml:146` `{DynamicResource subtalBrush}` (case typo → resolves to nothing); `GridViewGameOverview.xaml:105` references undefined `DetailsViewAllowUseOfLogos` (should be `GridViewAllowUseOfLogos` — grid logo toggle dead). Adjacent: `themeExtras.yaml` `BannersBySourceNamePath` points at an `Images/Banners/SourceName` directory that doesn't exist, and the `DetailsListSelectedGradient` key in `Constants.xaml` is defined-but-unused with two `GradientStop`s bound to an undefined `AccentIdleColor`. |
| Dead upstream palette | Pre-fork navy/brown/beige remnants (`MainColor #2C3A67`, `Brown #795548`, `CardBorderBrush #D4D0B8`, yellow `BackgroundToneColor`, three unused radial "tube" gradients, plus `ExpanderBackgroundBrush`, which hardcodes `MainColor`'s hex directly) — roughly **60 genuinely dead Color/Brush keys**, of 80 dead keys of any type. ⚠️ Not all are safe to delete: 19 are Playnite-global and `DuplicateHider_MaxNumberOfIcons` is read by its plugin — see HYP-195. |
| Structural duplication | The metadata-row block is duplicated across `DetailsViewGameOverview.xaml` and `GridViewGameOverview.xaml`. The full duplicated span is closer to **490 lines**, not 250 — the 16 metadata rows sit in one range while the HLTB and achievements blocks live ~230 lines earlier in each file. It is **not** byte-identical: the DuplicateHider host names genuinely differ (`DhDetailsSelectorHost`/`_SourceSelector1` vs `DhGridDetailsSelectorHost`/`_SourceSelector2`). Hardcoded HLTB hexes included. |
| ~~Zero render caching / virtualization tuning~~ **Not debt** | `CacheMode`: 0 uses despite 46 scale-targeting animation elements across 7 files; `Fant` on every grid cover. ✅ **Corrected twice.** (HYP-206) "no `VirtualizationMode=Recycling` anywhere" is true but **irrelevant** — Playnite sets it itself, as a local value, after the theme parses. (HYP-208) The 46/7 counts are exact but resolve to **14** real sites, and all 14 are disqualified — `CacheMode` should stay at 0. Playnite's own default theme also ships zero. This row describes a correct state, not debt. See F2 and F3. |
| Identity | `theme.yaml` still says `Name: Mythos, Author: bansakai, Version: 2.0` with all links pointing upstream. |

---

## Workstream A — Foundations: the VibeMythos design system

The invisible release. Everything in C–E gets cheaper and more consistent once this lands.
All of it lives in `source/Constants.xaml` + mechanical migration across the four style
directories.

### A1. Color: consolidate, name, purge

- Keep the neutral ramp and glass system exactly as they look today — codify, don't
  redesign.
- **One elevation/hover rule:** interactive surfaces use the overlay ramp
  (rest → `ContentBrushOverlay` `#1AFFFFFF` → hover `ContentBrushOverlayHover` `#33FFFFFF`
  → pressed/selected). Migrate the 26 hover brushes down to ~4 sanctioned ones; retire
  `HoverBrush`-as-background.
  ✅ **Corrected (HYP-206):** that is **3 call sites**, not one — `Menu.xaml:45`, `Thumb.xaml:51`,
  `Thumb.xaml:54`. Retire the *usage*; **keep the key**. `HoverBrush` is Playnite-global (one of the
  42 core paint keys), so deleting or renaming it hands core chrome back to Playnite's stock palette.
- Tokenize the strays: HLTB tri-color (`#008272/#0078d4/#2ea855`, duplicated in both
  overview files), destructive hover (`Simplebutton.xaml:444` `#c0392b` →
  `DestructiveColor`), scrim gradients, `Menu.xaml:10`, the `ToggleButton.xaml` animation
  target colors.
- ✅ **Corrected (HYP-206): the purge already happened.** HYP-195 removed 51 dead keys; `Constants.xaml`
  now holds **196 keys over 449 lines**. `MainColor` and `TooltipBackgroundBrush` were listed above as
  "dead upstream palette" and are **not** — both are Playnite-global core paint keys. Retint, never
  delete. Anything still outstanding here is naming/aliasing, not deletion.
- Purge the dead navy/brown/beige/radial keys. **Keep** the inverted `WhiteColor`/
  `BlackColor` hack (it forces Playnite-core lookups dark — load-bearing) but document it
  with a comment block, and alias the misspellings (`SubtalBrush` → `TextSubtleBrush`,
  `ActuallyWhiteBrushBrush` → `TrueWhiteBrush`) keeping old keys as deprecated aliases so
  nothing breaks.

### A2. Shape and space

- **Radius scale, 5 tiers:** `Radius/Control` 6 · `Radius/Inner` 10 · `Radius/Card` 16 ·
  `Radius/Panel` 22 · `Radius/Pill` (half-height). Migrate the 35 literals and collapse the
  14 tokens onto these; fix the sidebar 15/16 seam.
- **Spacing scale on a 4px grid:** `Space/1`=4 … `Space/8`=32 as `Thickness`/`sys:Double`
  tokens. New work must use them; migrate high-traffic surfaces (top panel, details view,
  grid drawer) opportunistically rather than big-bang.
- Opacity tokens: `Opacity/Disabled` 0.4, `Opacity/Secondary` 0.6 (today hardcoded in
  `Common.xaml:14,25`).

### A3. Typography: ship the fonts, finish the scale

- ✅ **Shipped in HYP-194.** Inter, Inter Tight and Inter Mod (all OFL-licensed) now live in
  `source/Typefaces/`. `Inter-Mod-Regular.ttf` had been committed under `Resources/`, which is
  not packaged into the theme — exactly why it never loaded — and was moved.

  ⚠️ **The folder must not be called `Fonts/`.** `Toolbox.exe pack` blacklists `^Fonts\\`
  (`Playnite.Toolbox/Themes.cs`) because Playnite's scaffolder puts its own common fonts
  there — a theme's `Fonts/` works when deployed by hand and is **silently dropped from the
  `.pthm`**. Verify every release by listing the packed archive, not just by deploying.

  **A fallback stack cannot substitute for shipping the files.** Comma fallback does work
  in general (`"Bogus, Segoe UI Variable Text"` → `Segoe UI Variable Text`), but WPF's
  fuzzy family matching resolves `Inter Tight` and `Inter Mod` to `Inter` *before* any
  fallback is consulted.

  **The URI mechanism is constrained** (traced through Playnite 10.56, 2026-08-17):
  `Playnite/Common/Xaml.cs` loads theme XAML with `XamlReader.Load(stream)` and **no
  `ParserContext`**, and `Themes.cs` assigns `ResourceDictionary.Source` only *after*
  parsing — too late to re-base the already-constructed `FontFamily` objects. So relative
  font URIs resolve against the **Playnite install root**, not the theme folder.
  `{ThemeFile}` can't help either: it runs the target property's `TypeConverter` (right
  shape for `FontFamily`) but `GetFilePath` does `File.Exists` on the relative path, so
  the mandatory `#FamilyName` fragment fails the check and it returns `null`.
  Measured working forms: `<dir>\#Inter Mod`, `<dir>\X.ttf#Inter Mod`, and `<dir>/#Inter Mod`
  *with* a base URI ending in `/`. A path with no fragment silently
  yields Arial. **The install-root-relative form is confirmed working on device**
  (`Themes/Desktop/<themeDir>/Typefaces/#Inter`) — verified 2026-08-17 by dropping the bare-name
  fallback in favour of Comic Sans and confirming the UI still rendered Inter after a
  restart. Still append fallbacks: a theme installed to `%AppData%\Playnite\Themes\` would
  miss the path, and the chain lets it degrade instead of break.
  **Variable fonts do work** — WPF enumerates `InterTight[wght].ttf` as family `Inter
  Tight` with all nine named weight instances (Thin→Black) addressable, so one 568 KB file
  covers every weight. Choose per family by the *reported family name*, not by format:
  Inter's variable file reports `Inter Variable Text` (wrong name for our token) so Inter
  ships as four statics, while Inter Tight ships as the single variable file. Watch the
  filename: `[wght]` is a PowerShell wildcard *and* illegal in a URI, so use
  `Copy-Item -LiteralPath` and rename on the way in.
- Own `FontSizeLarger`/`FontSizeLargest` in the theme's own `Constants.xaml` rather than
  inheriting Playnite's 20/29; migrate the 31 literal sizes onto the scale (13→14, 15→16,
  19→20); add weight tokens (`Font/Display` = Inter Tight SemiBold, `Font/Body` = Inter
  Regular, `Font/Label` = Inter Medium).
- Numeric UI (playtime, sizes, scores, achievement counts) gets tabular figures for
  stable alignment. While here, settle whether `MonospaceFontFamily` = `Inter Mod` is a
  misnomer — it looks like a modified Inter with tabular figures, not a true monospace.
- ✅ **Shipped in HYP-194.** The **63** hardcoded `"Segoe Fluent Icons, Segoe MDL2 Assets"`
  declarations (53 as a `FontFamily="…"` attribute, 10 as a `Setter` `Value`, 31 of them in
  `Media.xaml` alone) are now on a single `IconFontFamily` token, including the copy that was
  baked into the `IconFontStyle` style. The one `Marlett` usage is correctly left alone — swept,
  it would render a literal `6` instead of the filter-row chevron.

### A4. Motion vocabulary

Three duration tokens + two easings, as keyed resources next to the existing `FlyOutEase`
(`Constants.xaml:389` — ✅ **corrected (HYP-206)**; this was published as `:396`, then wrongly
"corrected" to `:360`, and is at `:389` as of `bba0dc2`. Grep for it, don't trust any of the three):

| Token | Value | Use |
| --- | --- | --- |
| `Motion/Fast` | 120ms | hover/pressed feedback |
| `Motion/Base` | 220ms | reveals, crossfades, drawers |
| `Motion/Slow` | 400ms | page-level entrances, hero transitions |
| `Ease/Standard` | CubicEase Out | everything by default |
| `Ease/Emphasized` | BackEase Out (amp 0.3) | playful accents: play button, favorites |

Migrate the 41 storyboards onto these (mechanical and easily reviewed — note the original "86" double-counted opening and closing tags and included a commented-out block).
Note: `Duration` cannot be templated everywhere via `DynamicResource` in triggers —
where WPF forces literals, the tokens still serve as the documented source of truth.

### A5. Repair and dedupe

- Fix the two silent breaks (`subtalBrush` casing, `DetailsViewAllowUseOfLogos` →
  `GridViewAllowUseOfLogos`), plus the stale `BannersBySourceNamePath` directory and the
  unused `DetailsListSelectedGradient`.
- Share the duplicated 250-line metadata block via styles in `Common.xaml`.
  ✅ **Corrected (HYP-206): new files are not categorically forbidden.** `ApplyTheme` accepts any path
  the default theme's dictionaries already merge, and **16 of those are still unclaimed** — including
  `DefaultControls/Border.xaml`, `DefaultControls/TextBlock.xaml` and `DefaultControls/Label.xaml`,
  which are natural homes for shared base styles. `Common.xaml` remains a fine choice, but it is a
  style preference now, not a constraint. See CLAUDE.md hard rule 1 for the full list and the
  regeneration command; HYP-212 confirms one on device first.

  ⚠️ **Share the chrome, not the elements.** The block is built from `PART_Elem*`-named
  elements, and Playnite resolves those by name within the *view's* namescope. Hoisting
  them into a shared `DataTemplate`/`ControlTemplate` puts them in a separate namescope
  and silently drops that row's functionality — the same failure class as the missing
  progress-bar parts in HYP-155. Extract only the row `Border` style (padding, brush,
  thickness), the `Label` style and the `SharedSizeGroup` column pattern; keep every
  named element inline in both views. That still roughly halves each copy.

---

## Workstream B — Identity: actually become VibeMythos

- ✅ **Shipped in HYP-200, and this bullet instructed the opposite of what shipped.** The plan said
  **"keep the `Id` (`Mythos_9f42c1a7-…`) unchanged"**. That was reversed deliberately: sharing
  upstream's Id meant bansakai's next release above our `Version` would resolve to *his* addon-database
  entry and, via `ExtensionInstaller.InstallPackedFile`'s recursive wipe, silently replace this fork
  with upstream Mythos on the user's next update check. The fork now carries its own
  `VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca`. **Do not "restore" the old Id.**
  `Name`, `Author`, links and `Version: 2.1` all shipped with it; `ThemeApiVersion` stays `2.9.0`.
  The Id↔font-chain coupling the bullet warned about is real and is covered by the CLAUDE.md validator.
  ⚠️ `Version` must still rise for the 3.0 release — the updater compares it, so shipping without a
  bump means existing installs never fetch the release.
- `Manifest/Addon_Manifest.yaml` + `Installer_Manifest.yaml`: new identity + 3.0 release
  entry.
- README rewrite: new hero banner, feature tour with fresh screenshots, credits chain
  preserved (sakasakiking → darklinkpower → bansakai), plugin pairing guide (which
  plugins light up which surfaces).
- Retire `UseMythosLogo` wording in `thememodifier.yaml` ("Use VibeMythos Icon…").
- Update the stale CLAUDE.md claims (progress-bar parts now exist; Constants count).

---

## Workstream C — Cinematic surfaces (the visible release)

Design direction for every surface: **full-bleed art, glass sheet on top, content in
cards, motion on entry.** Use the `frontend-design` skill when executing each of these.

### C1. Artwork crossfades (HYP-162)

The Aniki A/B pattern, pure XAML: two stacked `Image` layers, flip a bool on selection
change, `DataTrigger` storyboard crossfades opacity over `Motion/Base`. Apply to: ambient
backdrop, details cover/logo, grid-drawer art, Now Playing album art.

✅ **Corrected (HYP-206): the premise is wrong.** "Kills the single most un-premium behavior — the hard
cut on every selection change" does not describe the theme. The ambient backdrop **already crossfades**:
`Views/Library.xaml:22` uses Playnite's own `FadeImage` for `PART_ImageBackground`, exactly as stock
does. There is no hard cut to kill there. The genuinely un-transitioned surface is the **grid drawer**
(zero storyboards in `GridViewGameOverview.xaml`), which is why the 3.0-beta milestone opens with
HYP-217 rather than with this item. Keep this scoped to the surfaces that actually pop — and note the
proposed `NotifyOnTargetUpdated` retrigger is **not a property on `PluginSettings`**, so writing it is
a parse failure, i.e. a whole-theme failure (CLAUDE.md hard rule 10). HYP-162 is the spike.

### C2. Details view as hero page

`DetailsViewGameOverview.xaml` (1,916 lines) is the flagship and the biggest refactor
target. Recomposition, keeping all existing toggles working:

- **Hero band:** full-bleed backdrop (existing ambient system) + logo lockup
  (EML logo, else `Inter Tight` display title), primary action row (Play + achievements
  ring + HLTB chip), floating on glass.
- **Content sheet:** description, links, and new plugin shelves (C4/D) in cards on a
  glass sheet that begins below the hero.
- **Staggered entrance:** title → hero art → action row → metadata rows cascade in with
  ~40ms offsets, opacity+8px translate, `Motion/Slow` once per game change. One
  storyboard, huge perceived-quality gain.
- Metadata right rail consumes the shared block from A5.
- ~~Remove the `Margin="0,-9999,0,0"` off-screen video-loader hack in favor of a proper
  collapsed state.~~
  🛑 **Unsafe as written — do not execute (HYP-206).** The hack is load-bearing. The
  `ExtraMetadataLoader_VideoLoaderControl` at `DetailsViewGameOverview.xaml:763-768` is pushed
  off-screen but **must keep rendering**, because `:787-790` uses it as the `Visual` of the
  `VisualBrush` that fills the visible `Rectangle` inside `VideoDisplayGrid`. Collapsing it — or
  giving it `Visibility="Collapsed"`, zero size, or anything that stops it producing layout —
  removes the brush's source and the video area goes blank. That is a *worse* bug than the hack.
  Any replacement must keep a live, laid-out visual to feed the brush (e.g. clip or zero-opacity it
  rather than collapse it) and must be verified with a game that actually has a trailer. Tracked
  separately as HYP-223 and deliberately parked at Low priority. Independently re-verified
  2026-08-17 — this one came from a single agent and was the most dangerous claim in the audit.

### C3. Grid view as gallery

- ✅ **Corrected (HYP-206): both already ship.** `DerivedStyles/GridViewItemStyle.xaml` has the
  hover-lift (`ScaleTransform` to **1.0175**, 0.3s `CubicEase` out, `:35-85`) gated by the working
  `GridViewCoverZoomOnHover` ThemeModifier toggle via the `ZoomOnHoverProxy` `Tag` at `:22-23`, and
  the selection ring (`SelectionBorder`, `AccentHighlightBrush` on `IsSelected`, `:92-95`, with a
  `ContentBrushOverlayTwo` hover ring at `:87-90`). What is actually left is **tuning, not building**:
  1.0175 is subtle next to the proposed 1.03, there is no shadow, and the ring has no animated reveal.
  ~~Adding `CacheMode=BitmapCache` to the animated element remains valid and unshipped.~~
  🛑 **Not valid (HYP-208)** — grid items are virtualised *and recycled*, so the subtree structure
  changes on every recycle, which is the documented trigger for cache regeneration. A `Style`-level
  cache here makes scrolling worse while only ever benefiting the item under the cursor. See F2.
- **The details drawer currently pops with zero transition** (0 storyboards in
  `GridViewGameOverview.xaml`) — slide+fade it over `Motion/Base`, respecting
  `GridViewDetailsPosition`.
- Empty-state styling for filtered-to-nothing libraries.

### C4. Panels, search, chrome

- Filter panel / notification panel / search view: entrance transitions (today static),
  spacing-scale pass, consistent glass treatment with the sidebar's floating mode.
- Replace the notification panel's `ThicknessAnimation` (layout-thrashing,
  `MainWindow.xaml:23-55`) with a `TranslateTransform` slide.
- ~~Finish plugin-window polish (HYP-193)~~ ✅ **Shipped in PR #8** — this prose contradicted the plan's
  own Sequencing section, which already said so. Remaining scope was ruled out as a
  PlayniteAchievements limitation, not a theme bug.
- Finish the UniPlaySong top-panel story (HYP-159): themed transport styling via
  `TopPanelItem` containers + the Now Playing toast already shipped.
  ✅ **Corrected (HYP-206):** build against the real API — see the corrected UniPlaySong row in
  CLAUDE.md's cheat sheet. Three self-styled drop-ins already exist
  (`UPS_MediaController{Bar,Compact,Overlay}`), so the choice is *use them* vs *build custom transport*
  from `ActiveMedia*` state plus `playnite://uniplaysong/…` URIs — not "no controls exist". Settings
  paths are flat (`ActiveMediaIsPlaying`). ⚠️ The toast's storyboard lives in a `Style`, so it may not
  use `Storyboard.TargetName` — animate by property path (CLAUDE.md hard rule 11).

---

## Workstream D — Living library: plugin integrations

Research verdicts (2026-08-10, from source-level survey of `AddCustomElementSupport`
across the ecosystem). Guiding rule stays: **bind raw data, render in our language, and
every block must self-collapse when its plugin is absent** (`PluginStatus` gate + bind
wrapper visibility to the injected control's own `Visibility`).

### Tier 1 — biggest payoff

| Plugin | What we build |
| --- | --- |
| **ThemeOptions** (ashpynov) | The preset engine — see Workstream E. Also the only sanctioned way to load extra XAML. |
| **BackgroundChanger** (Lacro59) | Upgrade the ambient backdrop: `BackgroundChanger_PluginBackgroundImage` for per-game rotating/video backdrops; branch layout on `BackgroundIsVideo`. ImageRotater ships a BackgroundChanger-compatible shim, so we support both with one integration. |
| **GameActivity** (Lacro59) | A "Recent Session" row from pre-formatted strings (`LastPlaytimeSession`, `RecentActivity`, `AvgFpsAllSession`) — skip its LiveCharts chrome entirely. |
| **Game Relations** (darklinkpower) | "More like this" shelf on the details page: `SimilarGamesControl` / `SameSeriesControl` etc., four self-collapsing controls, near-zero risk. |

### Tier 2 — details-view depth

- **News Viewer**: news shelf + live Steam player count in the details header.
- **Review Viewer**: Steam review summary — *Steam-gated; only render for games with a
  Steam link.*
- **Steam Screenshots**: store screenshot gallery via `Content.ScreenshotsBitmapImages`
  laid out in our own strip (raw `BitmapImage`s, no plugin chrome). Complementary to
  **ScreenshotsVisualizer** (user's own captures via `ListScreenshots` → `Thumbnail`).
- **CheckDlc**: owned/unowned DLC section (`CheckDlc_PluginListDlcAll` or custom from
  `ListDlcs`).
- **CheckLocalizations**: language flag row (`PluginFlags`) now; full UI/audio/subtitle
  matrix from `ListNativeSupport` later.
- **LibraryManagement**: feature icon row (controller/cloud-save icons) — its controls
  **require an explicit `Height`** per the wiki.

### Tier 3 — differentiators to prototype

- **Web Explorer**: embedded store page tab with our own chrome via `BrowserCommands`
  (needs explicit `Height` + `UseLayoutRounding` on the parent, per wiki).
- **Friends Achievement Feed** (justin-delano, same author as our achievements plugin):
  `GameFeedTab` friend-activity feed.
- **MetadataUtilities** (HerrKnarz): structured tag/genre sections via
  `*PrefixItemControl` elements.
- **PlayState + BackToGame**: a "game is running" state — suspend/resume pill + jump-back
  button.

### Ruled out (verified no theme surface)

IsThereAnyDeal (no `AddCustomElementSupport` at all — it's a standalone window), Splash
Screen, JAST USA Library, Filter Presets Quick Launcher (rides our existing
`TopPanelItem`/`SidebarItem` styles — nothing to wire, just don't break it).

### Cross-cutting cautions

- The two plugin families use **incompatible `PluginStatus` identifier conventions**
  (Lacro59: bare GUID or SourceName; darklinkpower: `Name_GUID`). Maintain the id table
  in CLAUDE.md as integrations land — this is the #1 silent-failure source.
- **Key ownership:** ThemeOptions loads *after* ThemeModifier. Decide per key which
  plugin owns it, or settings will silently not stick (same failure mode as the old DKG
  Theme Modifier incident). Proposal: ThemeModifier keeps simple toggles/colors
  (existing **42** settings — ✅ corrected (HYP-206); `thememodifier.yaml` is 51 lines = 1 `Constants:`
  header + 8 section headers + 42 settings, and the README's "41" is wrong), ThemeOptions owns presets
  and anything new that needs sliders with steps, two-way state, or extra files.

---

## Workstream E — Visual Packs: presets via ThemeOptions

ThemeOptions gives radio-select **presets** with preview images, typed constants without
files, extra merged XAML, and live two-way variables. Hard rule (from its docs, and ours):
**the theme must remain fully functional with ThemeOptions absent** — `Constants.xaml`
keeps every default.

Ship 3.0 with constants-only presets (cheap, safe), holding extra-XAML packs for 3.1:

- **Appearance packs:** `Slate` (today's look, default) · `Noir` (true-black surfaces,
  heavier scrim — OLED-friendly) · `Vibrant` (stronger accent presence, brighter glass).
- **Accent packs:** Azure (default) · Violet · Emerald · Amber · Crimson — one
  `SolidColorBrush` cluster each over the existing accent token family (the tokens
  already exist: `AccentIdleBrush`/`Darker`/`Highlight`).
- **Density packs:** `Comfortable` (default) · `Compact` (tighter spacing tokens, smaller
  grid gaps) — this is exactly what the A2 spacing tokens make possible.
- Preview images shipped per preset; presets marked `NeedRestart` only where
  `StaticResource` consumption forces it.

---

## Workstream F — Performance: fast is premium

Ordered by expected impact; each verified on the real `F:\Playnite` install with a full
library before/after.

1. ~~**Grid cover scaling:** `Fant` → `HighQuality` (linear)~~
   🛑 **No-op — do not execute (HYP-206).** In WPF's `BitmapScalingMode`, **`Fant` and `HighQuality`
   are the same enum value**, and `Linear` and `LowQuality` are likewise the same. So this swap
   changes literally nothing, and the parenthetical "(linear)" describes the opposite of what
   `HighQuality` means. If cover scaling really is the frame-time cost, the only meaningful change is
   `Fant`/`HighQuality` → `LowQuality`/`Linear`, which is a visible quality regression and must be
   measured before it is chosen. Re-verify with a profiler on a full library, not by reasoning.
2. ~~**`CacheMode="BitmapCache"`** on every scale-animated element (cover hover-zoom, play
   button, sidebar items) — 46 scale-targeting animation elements currently re-rasterize per frame.~~
   🛑 **Ship zero `CacheMode` attributes — do not execute (HYP-208).**

   The counts are right and the conclusion is wrong, which is what makes this item dangerous:
   **46** scale-targeting animation elements across **7** files is exact, and `CacheMode` really
   does appear 0 times. But 46 counts animation *elements* — each transform needs a `ScaleX` and a
   `ScaleY` animation, and an Enter and an Exit copy, so one hover effect costs four. The number of
   places an attribute would actually be typed is **14 `ScaleTransform` declarations**, and every
   one of them is disqualified:

   | Sites | Why not |
   |---|---|
   | 2 — `ProgressBar.xaml:34,:42` | `LayoutTransform`, not `RenderTransform`. `BitmapCache` caches *rendered output*, so it cannot touch the per-frame measure/arrange these cause — and the rectangles are `Fill="{x:Null}"`, so there is nothing to rasterise either. |
   | 2 — `DetailsViewItemStyle.xaml:42,:51` | 5px-wide solid-colour bars. Nothing to cache. |
   | 8 — `PlayButton.xaml:60,:224`, `DetailsViewGameOverview.xaml:859,:919,:984,:1871`, `ComboBoxList.xaml:187,:193`, `SidebarItem.xaml:48` | All contain text or icon-font glyphs — exactly the content a cache degrades. |
   | 2 — `GridViewItemStyle.xaml:8-11` and the grid cover | Virtualised **and recycled**, so the subtree structure changes on every recycle, which is the documented trigger for cache regeneration. Caching here makes scrolling worse while only ever benefiting the item under the cursor. |

   Three facts from Microsoft's `BitmapCache` documentation kill the general case, none of them
   obvious from the plan's framing:
   - `EnableClearType` defaults to **false**, so all text inside a cache renders with grayscale
     antialiasing — permanently, not just while animating. The cost is paid at rest, which is where
     essentially all viewing time is spent.
   - "RenderOptions and TextOptions do not propagate through a cached element." This theme sets
     `TextOptions.TextFormattingMode="Ideal"` at the window level (`MainWindowStyle.xaml:8-9`), so
     any cache placed between the window and a text element silently severs it — a second text
     regression layered on the first.
   - `RenderAtScale` is not a free fix: it multiplies the cache surface by the square of the factor
     and forces regeneration.

   The premise that these elements "currently re-rasterize per frame" is true only of the vector and
   glyph content — and that re-rasterisation *is* the sharpness. `BitmapCache` stops both, because
   they are the same mechanism. Playnite's own default theme agrees by omission: zero `CacheMode`
   across its entire tree.

   If a future session still wants the grid-cover case, the bar is: storyboard-scoped only (an
   `ObjectAnimationUsingKeyFrames` toggling `CacheMode` on at `MultiDataTrigger.EnterActions` and
   back to `x:Null` on exit), never a `Style`-level attribute, and measured on the real library
   before merge.
3. ~~**Virtualization spike:** `VirtualizingPanel.VirtualizationMode="Recycling"` + `ScrollUnit`
   on the games list.~~
   🛑 **No-op from the theme — do not execute (HYP-206).** Playnite already sets all three, as
   **local values**, in `OnApplyTemplate` — i.e. *after* theme XAML is parsed, so a theme attribute on
   `PART_ListGames` is overwritten every time. Verified in Playnite's source for **both** views:
   `LibraryGridView.cs` sets `ScrollUnit.Pixel`, `IsVirtualizingWhenGrouping=true` and
   `VirtualizationMode.Recycling`; `LibraryDetailsView.cs` sets the same three plus
   `CacheLength(5, Item)`. Local values beat style/template setters in WPF's precedence order, so
   there is nothing for the theme to win here.

   The *consequence* is worth keeping, though, and inverts the original caution: recycling is
   **already on in production**, so the DuplicateHider recycling comment at `Common.xaml:116-120`
   describes a live condition, not a hypothetical one.

   ~~`DataGrid.xaml:80` disabling `CanContentScroll` in one branch is a separate, still-valid fix.~~
   🛑 **Also drop this (HYP-208).** The line number is exact, but the line is **byte-for-byte
   identical to Playnite's own default theme** at the same line — it is stock WPF, not something
   this fork introduced. It governs an *implicit* `DataGrid` style that the library views never use
   (they use `ExtendedListBox`), and the trigger only fires under grouping, which nothing here does.
   Flipping it without also supplying `IsVirtualizingWhenGrouping`/`ScrollUnit` would trade smooth
   pixel scrolling for jumpy item scrolling with no virtualization.
4. Replace the notification panel's margin animation with a transform (C4).
5. Hygiene. ✅ **Corrected (HYP-206) on both counts:**
   - ~~delete the two unfrozen, unused `ImageBrush`es (`Constants.xaml:261-271`)~~ — **already done in
     HYP-195.** There are now **zero** `ImageBrush` matches anywhere in `source/`.
   - "12 scattered `UseLayoutRounding`/`SnapsToDevicePixels` declarations" is **115** — 109
     `SnapsToDevicePixels` + 6 `UseLayoutRounding`. Consolidating to the window root is therefore a
     ~115-site mechanical edit, not a trivial one, and it is **not** a pure lift: `CheckBox.xaml:31-32`
     sets both to `False` deliberately and must be preserved. Given hard rule 10 (one parse error
     drops the whole theme), do this after CI lands, not before.
   - Freezing freezables: **measured, and the answer is "only `Constants.xaml`, and it is marginal"**
     (HYP-208). The tree holds 163 `Freezable` declarations; 17 already carry `popt:Freeze`, 28
     cannot be frozen at all (they bear a `Binding`/`DynamicResource`), and of the remaining 118
     only the **67 keyed resources in `Constants.xaml`** are worth touching — the other 68 are inline
     inside `ControlTemplate`s, which **WPF already freezes automatically at template-seal time**
     (verified: a template-inline brush marked `popt:Freeze="False"` still reports `IsFrozen=True`).
     Adding `Freeze` there is pure typo risk for zero gain.

     Safety came out fine: freezing does **not** break ThemeModifier — Lacro59's `AddResources()`
     does `Application.Current.Resources[key] = <new brush>`, a replacement, never a mutation — and
     it does not break the `Background.Color` storyboards, because WPF auto-clones a frozen brush
     along a complex property path.

     ⚠️ The parse-error landmine is **not** where the plan assumed. `mc:Ignorable="PresentationOptions"`
     — the pattern Microsoft's own docs recommend — **silently disables the freeze** under
     `XamlReader.Load` (`IsFrozen=False`), so you get the risk and none of the benefit. Meanwhile a
     typo in the namespace, or an `mc:Ignorable` naming an undeclared prefix, is a hard throw, which
     by hard rule 10 costs the entire theme. Declare `xmlns:popt` **only**, with no `mc:Ignorable`.

     Benefit at realistic scale is small: at 500 concurrent references to one brush, attach is
     **20.7ms unfrozen vs 17.2ms frozen**. It only becomes dramatic past ~2,000 references
     (20,958ms vs 963ms at 20,000), which this theme does not approach. **Do it after CI is
     merged, or not at all** — 3.5ms does not justify 67 hand edits to the one file whose failure
     mode is total.

---

## Workstream G — Quality and release infrastructure

- **CI (HYP-168), upgraded for 3.0:** XAML well-formedness, localization parity,
  `thememodifier.yaml` key resolution, **plus new lints the design system makes
  possible:** no raw hex outside `Constants.xaml` (allowlist for the benign
  `OpacityMask` cases), no literal `CornerRadius`/`FontSize` outside token files, no
  `StaticResource` on ThemeModifier-exposed keys.
- **Localization (HYP-166).** ✅ **Corrected (HYP-206)** — re-counted 2026-08-17 with the namespace-aware
  `Get-Keys`: it is **7** Playnite-global `LOC*` overrides, not 16 (`LOCAddonChangesRestart`,
  `LOCExitAppLabel`, `LOCNotesLabel`, `LOCOpenPlaynite`, `LOCPlayGame`, `LOCSettingsRestartNotification`,
  `LOCVersionLabel`), and **3** missing keys, not 2 (`LOCAddonChangesRestart`,
  `LOCSettingsRestartNotification`, `LOCMythos_NowPlaying`). `de_DE`'s 9 stale keys are **already
  gone** — all 10 locales now sit at exactly 35 keys with 0 extras. CLAUDE.md's Known-state section
  was right and this bullet was stale. Remaining: back-fill the 3, full pt-BR pass, and note that
  `LOCPlayGame` is deliberately overridden as a ThemeModifier `Terminology` entry — retiring it means
  retiring that setting too. New 3.0 strings are `LOCMythos_`-prefixed from day one.
- SonarQube quality gate green on every PR (`sonar analyze -p alessandrocaetanob_VibeMythos`).
- Release checklist: deploy → visual pass → `Toolbox.exe pack` → `Toolbox.exe verify addon`
  → screenshots → `Installer_Manifest.yaml` entry.

---

## Sequencing

Four phases, each shippable; existing Linear issues slot in where noted.

| Phase | Contents | Existing issues |
| --- | --- | --- |
| **3.0-alpha "Foundation"** | A1–A5 (tokens, fonts, repairs, dedupe) · B (identity) · F1/F2/F5 (safe perf) | HYP-194 (fonts), HYP-195 (repairs), HYP-196 (metadata dedupe), HYP-197 (colour), HYP-198 (shape/space), HYP-199 (motion), HYP-200 (identity), HYP-166 (loc hygiene) |
| **3.0-beta "Cinema"** | C1–C4 (crossfades, hero details, grid gallery, panels) · finish HYP-159 | HYP-162, HYP-156 |
| **3.0 "Alive"** | D Tier 1 (ThemeOptions, BackgroundChanger, GameActivity, GameRelations) · E (constants presets) · G (CI, release) | HYP-164, HYP-161, HYP-165, HYP-167, HYP-168 |
| **3.1+ "Beyond"** | D Tier 2 & 3 shelves · extra-XAML visual packs · F3 virtualization experiment | — |

The 3.0-alpha issues are now open (HYP-194 through HYP-200). Still to be filed as their
phases come up: details hero recomposition · grid drawer transition · staggered entrance ·
BackgroundChanger backdrop · GameActivity session row · GameRelations shelf · ThemeOptions
preset engine · accent/density packs · perf pass (scaling+caching) · CI lint upgrades ·
README/screenshot refresh.

HYP-193 (plugin window polish) shipped in PR #8; its remaining scope was ruled out as a
PlayniteAchievements limitation rather than a theme bug.

---

## Risks and constraints

- ~~**No new XAML files** without ThemeOptions installed~~ — ✅ **corrected (HYP-206), then verified
  on device (HYP-212, 2026-08-19):** 16 default-theme paths are claimable today without any plugin,
  and the theme's copy wins over the default's (CLAUDE.md hard rule 1 carries the run table).
  ThemeOptions is only needed for paths *outside* that list, which leaves it justified by the preset
  engine alone rather than by extra-XAML loading. Every ThemeOptions-dependent feature still needs a
  no-plugin default.
- **One XAML parse error reverts the user to Playnite's default theme** — not one broken file, the
  whole theme (`ApplyTheme` pre-flights everything and `break`s on the first throw). This is the
  binding constraint on the ~500-site token migration and the reason CI (HYP-168) must land first.
- ~~**Font shipping mechanism** needs the on-device spike before committing.~~ ✅ **Resolved — shipped
  in HYP-194.** The install-root-relative form works on this portable install; fallbacks are appended
  for standard installs where the app base and the theme directory diverge.
- ~~**Recycling vs injected controls** (F3) can corrupt plugin UI — experiment behind measurement.~~
  ✅ **Corrected (HYP-206):** there is no experiment to run — Playnite forces recycling on regardless
  of the theme (see F3), so this is the *current* production condition rather than a change under
  consideration. Any DuplicateHider icon corruption is happening today.
- **ThemeModifier vs ThemeOptions key ownership** must be decided before E lands.
- **Upstream sync:** Mythos ships all default-theme files; any Playnite release touching
  theme files needs a diff pass (watch Playnite releases; 10.56 is the verified baseline).
- The audit was taken from the 2026-08-10 tree and re-verified on **2026-08-17**. That
  pass corrected three claims: `FontSizeLarger`/`FontSizeLargest` do resolve (via
  Playnite's default theme), `Images/Banners/UnknownLibrary.png` does exist, and the
  literal counts were low (48 `CornerRadius`, 63 icon-font declarations — of which 53 are the
  attribute form the original count measured). Re-verify line
  numbers again before executing individual items.

## Verification (per phase)

1. Static: XAML well-formedness + localization parity + thememodifier resolution
   (CLAUDE.md commands), SonarQube gate.
2. Deploy to `F:\Playnite\Themes\Desktop\VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca` via
   `Copy-Item` (never move) — ✅ **path corrected (HYP-206)**; the old `Mythos_9f42c1a7-…` folder is
   upstream's Id and is not where this theme deploys. Check for an `%AppData%` shadow first (it wins
   over the install dir), then restart Playnite and run the visual checklist per touched surface —
   **with the plugin matrix both ways** (each integrated plugin installed and uninstalled; nothing may
   leave an empty husk).
3. Perf: scroll the full library in Grid view before/after F changes; hover-zoom a row of
   covers; watch for dropped frames at 60Hz.
4. Package: `Toolbox.exe pack` + `verify addon` clean.
