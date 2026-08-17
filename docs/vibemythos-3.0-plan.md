# VibeMythos 3.0 — Premium Desktop Library

Date: 2026-08-10
Status: proposed plan
Baseline: Mythos 2.0 fork, Playnite 10.56, `ThemeApiVersion 2.9.0` (verified current — no bump needed)

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

Full inventory was taken from the current tree (79 XAML files, ~11.6k lines). What it found
shapes every workstream below.

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
| Hover chaos | ~133 `Setter`s inside `IsMouseOver` triggers, resolving to **27 distinct brush tokens** (33 counting hardcoded literal colours). `HoverBrush` (`#E7E9EA`, a *foreground*) is used as a background exactly once, in `Menu.xaml` — a one-off fix, not the pattern this row originally implied. |
| Type scale half-adopted | 31 literal `FontSize` (13/15/19 aren't even in the scale) vs 39 tokenized. `FontSizeLarger`/`FontSizeLargest` are used but not defined *by this theme* — they resolve only because Playnite's default theme defines them (20/29) and merges first. Not a break, but the theme doesn't own its own display size, including on the game title (`DetailsViewGameOverview.xaml:735`). |
| Silent breakage | Two real ones: `ComboBox.xaml:146` `{DynamicResource subtalBrush}` (case typo → resolves to nothing); `GridViewGameOverview.xaml:105` references undefined `DetailsViewAllowUseOfLogos` (should be `GridViewAllowUseOfLogos` — grid logo toggle dead). Adjacent: `themeExtras.yaml` `BannersBySourceNamePath` points at an `Images/Banners/SourceName` directory that doesn't exist, and the `DetailsListSelectedGradient` key in `Constants.xaml` is defined-but-unused with two `GradientStop`s bound to an undefined `AccentIdleColor`. |
| Dead upstream palette | Pre-fork navy/brown/beige remnants (`MainColor #2C3A67`, `Brown #795548`, `CardBorderBrush #D4D0B8`, yellow `BackgroundToneColor`, three unused radial "tube" gradients, plus `ExpanderBackgroundBrush`, which hardcodes `MainColor`'s hex directly) — roughly **60 genuinely dead Color/Brush keys**, of 80 dead keys of any type. ⚠️ Not all are safe to delete: 19 are Playnite-global and `DuplicateHider_MaxNumberOfIcons` is read by its plugin — see HYP-195. |
| Structural duplication | The metadata-row block is duplicated across `DetailsViewGameOverview.xaml` and `GridViewGameOverview.xaml`. The full duplicated span is closer to **490 lines**, not 250 — the 16 metadata rows sit in one range while the HLTB and achievements blocks live ~230 lines earlier in each file. It is **not** byte-identical: the DuplicateHider host names genuinely differ (`DhDetailsSelectorHost`/`_SourceSelector1` vs `DhGridDetailsSelectorHost`/`_SourceSelector2`). Hardcoded HLTB hexes included. |
| Zero render caching / virtualization tuning | `CacheMode`: 0 uses despite 46 scale-targeting animation elements across 7 files; `Fant` (most expensive scaler) on every grid cover; no `VirtualizationMode=Recycling` anywhere. |
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
- Tokenize the strays: HLTB tri-color (`#008272/#0078d4/#2ea855`, duplicated in both
  overview files), destructive hover (`Simplebutton.xaml:444` `#c0392b` →
  `DestructiveColor`), scrim gradients, `Menu.xaml:10`, the `ToggleButton.xaml` animation
  target colors.
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
(`Constants.xaml:396`):

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
- Share the duplicated 250-line metadata block via styles in `Common.xaml` (new files are
  forbidden; `Common.xaml` is the sanctioned shared home).

  ⚠️ **Share the chrome, not the elements.** The block is built from `PART_Elem*`-named
  elements, and Playnite resolves those by name within the *view's* namescope. Hoisting
  them into a shared `DataTemplate`/`ControlTemplate` puts them in a separate namescope
  and silently drops that row's functionality — the same failure class as the missing
  progress-bar parts in HYP-155. Extract only the row `Border` style (padding, brush,
  thickness), the `Label` style and the `SharedSizeGroup` column pattern; keep every
  named element inline in both views. That still roughly halves each copy.

---

## Workstream B — Identity: actually become VibeMythos

- `source/theme.yaml`: `Name: VibeMythos`, `Version: 3.0`, author `alessandrocaetanob
  (based on Mythos by bansakai)`, links → this fork. **Keep the `Id`
  (`Mythos_9f42c1a7-…`) unchanged** — changing it orphans every existing install's update
  path and the deployed-folder mapping, **and silently breaks all three font tokens**, which
  embed the Id as a path segment (HYP-194; CLAUDE.md carries a validator for the coupling).
  Keep `ThemeApiVersion: 2.9.0`.
  ⚠️ Do bump `Version` — it is still `2.0`. The updater keys off it, so shipping 3.0 without
  the bump means existing installs never fetch the release and the bundled fonts never arrive.
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
backdrop, details cover/logo, grid-drawer art, Now Playing album art. Kills the single
most un-premium behavior in the theme — the hard cut on every selection change.

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
- Remove the `Margin="0,-9999,0,0"` off-screen video-loader hack in favor of a proper
  collapsed state.

### C3. Grid view as gallery

- Cover hover: lift (scale 1.03 + stronger shadow) with `CacheMode=BitmapCache` on the
  animated element; selection ring in accent with animated reveal.
- **The details drawer currently pops with zero transition** (0 storyboards in
  `GridViewGameOverview.xaml`) — slide+fade it over `Motion/Base`, respecting
  `GridViewDetailsPosition`.
- Empty-state styling for filtered-to-nothing libraries.

### C4. Panels, search, chrome

- Filter panel / notification panel / search view: entrance transitions (today static),
  spacing-scale pass, consistent glass treatment with the sidebar's floating mode.
- Replace the notification panel's `ThicknessAnimation` (layout-thrashing,
  `MainWindow.xaml:23-55`) with a `TranslateTransform` slide.
- Finish plugin-window polish (HYP-193) so Settings/plugin dialogs stop looking
  un-themed: tab affordance, control contrast in `DefaultControls/`.
- Finish the UniPlaySong top-panel story (HYP-159): themed transport styling via
  `TopPanelItem` containers + the Now Playing toast already shipped.

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
  (existing 41 settings), ThemeOptions owns presets and anything new that needs sliders
  with steps, two-way state, or extra files.

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

1. **Grid cover scaling:** `Fant` → `HighQuality` (linear) for covers in
   `GridViewItemTemplate.xaml:30,33`; keep `Fant` only for large, static hero art. Fant
   on every cover is the likeliest frame-time cost at scroll speed.
2. **`CacheMode="BitmapCache"`** on every scale-animated element (cover hover-zoom, play
   button, sidebar items) — 46 scale-targeting animation elements currently re-rasterize per frame.
3. **Virtualization spike:** `VirtualizingPanel.VirtualizationMode="Recycling"` +
   `ScrollUnit` on the games list. ⚠️ Recycling interacts with plugin-injected controls
   (the DuplicateHider recycling comment at `Common.xaml:116-120` exists for a reason) —
   this is a measured experiment, not a default-on change. Also fix
   `DataGrid.xaml:80` disabling `CanContentScroll` in one branch.
4. Replace the notification panel's margin animation with a transform (C4).
5. Hygiene: delete the two unfrozen, unused `ImageBrush`es (`Constants.xaml:261-271`);
   `UseLayoutRounding`/`SnapsToDevicePixels` once at the window root instead of 12
   scattered declarations; freeze anything freezable that remains.

---

## Workstream G — Quality and release infrastructure

- **CI (HYP-168), upgraded for 3.0:** XAML well-formedness, localization parity,
  `thememodifier.yaml` key resolution, **plus new lints the design system makes
  possible:** no raw hex outside `Constants.xaml` (allowlist for the benign
  `OpacityMask` cases), no literal `CornerRadius`/`FontSize` outside token files, no
  `StaticResource` on ThemeModifier-exposed keys.
- **Localization (HYP-166):** stop overriding the 16 Playnite-global `LOC*` keys, add the
  2 missing keys to all 10 locales, drop `de_DE`'s 9 stale keys, full pt-BR pass. New 3.0
  strings are `LOCMythos_`-prefixed from day one.
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

- **No new XAML files** without ThemeOptions installed — shared code goes to
  `Common.xaml`; every ThemeOptions-dependent feature needs a no-plugin default.
- **Font shipping mechanism** needs the on-device spike before committing. Theme XAML
  parses with no BaseUri (see A3), so the only candidate is an app-base-relative path,
  which depends on where the theme is installed. If every form fails, make the tokens
  honest with a real fallback stack and ship an optional font-installer note (never a
  registry-hack requirement).
- **Recycling vs injected controls** (F3) can corrupt plugin UI — experiment behind
  measurement, keep revert path.
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
2. Deploy to `F:\Playnite\Themes\Desktop\Mythos_9f42c1a7-…` via `Copy-Item` (never move),
   restart Playnite, run the visual checklist per touched surface — **with the plugin
   matrix both ways** (each integrated plugin installed and uninstalled; nothing may leave
   an empty husk).
3. Perf: scroll the full library in Grid view before/after F changes; hover-zoom a row of
   covers; watch for dropped frames at 60Hz.
4. Package: `Toolbox.exe pack` + `verify addon` clean.
