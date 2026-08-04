# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

**VibeMythos** is a fork of [Mythos](https://github.com/bansakai/Mythos) (by bansakai), a Fluent UI–inspired **desktop-mode theme for [Playnite](https://playnite.link)** (WPF/XAML, Windows). The fork exists to build improvements on top of Mythos 2.0: plugin integrations (achievements, music, source badges), progress/loading UI, Aniki-inspired visual patterns, and localization cleanup.

Work is tracked as issues in **Linear** (project "VibeMythos", team "Hyperius"). Repo artifacts (commits, code comments, docs) are written in **English**.

## Repository layout

| Path | Purpose |
|---|---|
| `source/` | The actual theme (extracted from the upstream 2.0 `.pthm` package, which is just a zip). This is what gets edited and packaged. |
| `source/theme.yaml` | Theme manifest: `Id`, `Version`, `ThemeApiVersion` (2.9.0 — matches current Playnite `DesktopApiVersion`; a major bump breaks loading). |
| `source/Constants.xaml` | Colors, brushes, sizes, and all ThemeModifier-editable toggles (`sys:Boolean` etc.). |
| `source/Common.xaml`, `source/Media.xaml` | Base styles / icons and image specs. |
| `source/Views/` | Library views and panels (`MainWindow`, `TopPanel`, `DetailsViewGameOverview`, `GridViewGameOverview`, `Sidebar`, `NotificationPanel`, …). |
| `source/DefaultControls/` | Restyles of built-in WPF controls (Button, ProgressBar, …). |
| `source/DerivedStyles/` | Styles for specific Playnite cases (PlayButton, GridViewItemTemplate, MainWindowStyle, …). |
| `source/CustomControls/` | Styles for Playnite custom controls (SidebarItem, TopPanelItem, SearchBox, …). |
| `source/Localization/` | Theme strings, one `ResourceDictionary` per locale (11 locales). |
| `source/thememodifier.yaml` | ThemeModifier plugin manifest — exposes `Constants.xaml` keys as user settings. |
| `source/themeExtras.yaml` | ThemeExtras plugin manifest — banner paths, persistent paths. |
| `Manifest/` | Playnite addon-database manifests (`Addon_Manifest.yaml`, `Installer_Manifest.yaml` with release history). |
| `Resources/`, `Screenshots/` | README/store assets, not part of the packaged theme. |

## Hard rules of Playnite desktop theme development

1. **You cannot add new XAML files.** Playnite's theme loader (`Playnite/Themes.cs`) only merges files whose relative path exists in the built-in default theme. New styles must go into an existing file. (The ThemeOptions plugin is the only sanctioned workaround.)
2. **Markup extensions:**
   - `{PluginSettings Plugin=<SourceName>, Path=<prop>, FallbackValue=..., Mode=...}` — reads a plugin's exposed settings/data. Uses the plugin **SourceName** (e.g. `SuccessStory`, `ThemeExtras`).
   - `{PluginStatus Plugin=<AddonId>, Status=Installed}` — visibility gate on plugin presence. Uses the **AddonId** (e.g. `playnite-successstory-plugin`, `felixkmh_Extras_Plugin`).
   - A binding targeting `Visibility` gets a `BooleanToVisibilityConverter` injected automatically — no explicit converter needed.
   - `{ThemeFile 'Images/x.png'}` for theme-owned assets; `{Settings <prop>}` for Playnite settings; `{Api Notifications.Count}` for API values.
3. **ThemeModifier keys** (everything listed in `thememodifier.yaml`) must be consumed via `DynamicResource`, never `StaticResource`, or live updates break. Every yaml entry must have a matching key in `Constants.xaml`; entries without a match render as section headers.
4. **Plugin-injected controls**: declare `<ContentControl x:Name="<SourceName>_<ElementName>" />`; Playnite fills it if the plugin is installed, otherwise it renders nothing. To hide wrapper chrome, bind to the injected control's own `Visibility` (`{Binding ElementName=..., Path=Visibility}`) — Lacro59-style controls collapse themselves when they have no data.
5. **Localization** (`source/Localization/`):
   - `en_US.xaml` must exist or NO localization loads at all.
   - Only `sys:String` entries survive loading; anything else is stripped.
   - Consume with `DynamicResource` (dictionaries merge after theme XAML).
   - Prefix theme-owned keys with `LOCMythos_`. Avoid overriding Playnite-global `LOC*` keys — they leak outside the theme (the current source still does this in ~16 places; cleanup is a tracked issue).
6. **Template part names matter**: controls like the Top Panel bind by `PART_*` name (`PART_ProgressGlobal`, `PART_TextProgressText`, `PART_ButtonProgressCancel` for global task progress; `PART_ProgressStatus` in SidebarItem). Omitting a part silently drops that functionality — Mythos 2.0 currently omits the three global-progress parts, which is why users see no task progress bar (tracked issue).

## Plugin integration cheat sheet

| Plugin | SourceName | AddonId / GUID | Key surface |
|---|---|---|---|
| [SuccessStory](https://github.com/Lacro59/playnite-successstory-plugin/wiki/Addition-in-a-custom-theme) (Lacro59) | `SuccessStory` | `cebe6d32-8c46-4459-b993-5a5189d60788` | Controls `SuccessStory_Plugin{ViewItem,Button,Chart,List,CompactList,CompactUnlocked,CompactLocked,ProgressBar,UserStats}`; data `HasData, Is100Percent, Unlocked, Locked, Total, Percent, TotalGamerScore, Common/Rare/UltraRare, ListAchUnlockDateDesc`; toggles `EnableIntegration*`. Custom button wrapper: `PART_CustomScButton`. |
| [Playnite Achievements](https://github.com/justin-delano/PlayniteAchievements/wiki) (justin-delano) | `PlayniteAchievements` | see its `extension.yaml` | Modern controls `PlayniteAchievements_Achievement{Button,ProgressBar,CompactList,BarChart,PieChart,Stats,DataGrid,ViewItem,…}`; legacy SuccessStory-shaped bindings (`HasData/Total/Percent/…`); theme-overridable toast via `PlayAch.Template.AchievementToast` in `PlayniteAchievements/AchievementToast.xaml`. Ships a Theme Migration tool that rewrites installed theme files — support both naming schemes. |
| [UniPlaySong](https://github.com/aHuddini/UniPlaySong) (aHuddini) | `UniPlaySong` | — | Desktop-capable. Elements `UPS_MusicControl` (Tag="True" pauses music), `UPS_NowPlayingMiniPlayer(Compact)`, `UPS_MediaController{Overlay,Bar,Compact}`; paths `NowPlayingTitle/Artist/AlbumArtPath`, `ActiveMedia{IsPlaying,Progress,PositionText,…}`, `IsMusicChanged`; URI commands `playnite://uniplaysong/{play,pause,next,…}`. Theme can ship `audio/UPS_BackgroundAudio.mp3` and `audio/Achievements/{rarity}.wav`. Ignores muted MediaElements (EML trailer coexistence). See `docs/dev_docs/THEME_INTEGRATION_GUIDE.md` in its repo. |
| [ThemeExtras](https://github.com/felixkmh/ThemeExtras-for-Playnite/wiki) (felixkmh) | `ThemeExtras` | `felixkmh_Extras_Plugin` | Controls `ThemeExtras_{User,Community,Critic}Rating`, `ThemeExtras_Settable{Favorite,UserScore,Hidden,CompletionStatus}`, `ThemeExtras_Banner`, `ThemeExtras_Links`; commands `Commands.{Back,Forward,SwitchMode,OpenPluginSettings,…}`; converter `UrlToAsyncIconConverter` (URL→favicon); `themeExtras.yaml` supports `WebsiteIconsPath`, `BannersBySourceNamePath`, `Recommendations`, `PersistentPaths` (images inside need `CacheOption=OnLoad`). |
| [ThemeModifier](https://github.com/Lacro59/playnite-thememodifier-plugin/wiki/Integrate-editable-constants) (Lacro59) | `ThemeModifier` | `playnite-thememodifier-plugin` | `thememodifier.yaml` next to `theme.yaml`; types Boolean/String/Double/Int/Color/Brush/Visibility/Alignments; numeric ranges `Key(min,max): Label`. |
| [HowLongToBeat](https://github.com/Lacro59/playnite-howlongtobeat-plugin/wiki/Addition-in-a-custom-theme) (Lacro59) | `HowLongToBeat` | `e08cd51f-9c9a-4ee3-a094-fde03b55492f` | Controls `HowLongToBeat_Plugin{Button,ProgressBar,ViewItem}`; data `HasData`, `MainStoryFormat/MainExtraFormat/CompletionistFormat` (pre-formatted strings — enough to build a fully custom row). |
| [ExtraMetadataLoader](https://github.com/darklinkpower/PlayniteExtensionsCollection/wiki/Extra-Metadata-Loader-theme-controls) (darklinkpower) | `ExtraMetadataLoader` | `705fdbca-e1fc-4004-b839-1d040b8b4429` | Controls `..._LogoLoaderControl(_DisableOpacityAnimation)`, `..._VideoLoaderControl_{Controls,NoControls}_{Sound,NoSound}` (bind own buttons to `Content.VideoPlayCommand`/`Content.VideoMuteCommand`); settings `EnableVideoPlayer, EnableLogos, LogoMax{Width,Height}, Logo{Horizontal,Vertical}Alignment`; per-game `IsLogoAvailable, IsAnyVideoAvailable, IsVideoPlaying`. |
| [DuplicateHider](https://github.com/felixkmh/DuplicateHider) (felixkmh) | `DuplicateHider` | `felixkmh_DuplicateHider_Plugin` | Source-icon selectors `DuplicateHider_SourceSelector`(`0`–`9`); theme supplies icons via resource keys `DuplicateHider_<SourceName>_Icon` (BitmapImage), `DuplicateHider_MaxNumberOfIcons`, styles `DuplicateHider_Icon{ContentControl,StackPanel}Style`. The standard route for Steam/GOG/Epic badges. |
| AnikiHelper (Mike-Aniki) | — | — | **Fullscreen-only — do not use in this desktop theme.** Its patterns (A/B image crossfade via `PathA/PathB` + flip bool, stamp-retriggered storyboards) are portable and worth copying in pure XAML. |

Reference themes with public source: [Helium](https://github.com/darklinkpower/Helium), [Nova-X](https://github.com/darklinkpower/Nova-X), [Stardust](https://github.com/darklinkpower/Stardust) (darklinkpower — canonical plugin-wiring examples), [eMixedNite](https://github.com/eminaguil/eMixedNite), [Aniki ReMake](https://github.com/Mike-Aniki/Aniki-ReMake) (fullscreen, design reference).

## Build, test, validate

- **This repo is developed in a Linux container; Playnite is Windows-only.** The theme cannot be run here. What CAN be validated here:
  - XAML well-formedness: every `source/**/*.xaml` must parse as XML.
  - Localization: `en_US.xaml` exists; locale files contain only `sys:String`; locale keys ⊆ `en_US` keys.
  - `thememodifier.yaml` keys have matching `x:Key` entries in `Constants.xaml`.
- **Real testing happens on the user's Windows PC**: copy/extract `source/` to `%AppData%\Playnite\Themes\Desktop\Mythos_9f42c1a7-6d8e-4b3f-b0a2-7e9c5d3f18a4\`, restart Playnite, select the theme in Settings → Appearance. No hot reload.
- **Packaging** (Windows, from the Playnite install dir): `Toolbox.exe pack <themeDir> <outDir>` → `.pthm`; `Toolbox.exe verify addon Manifest/Addon_Manifest.yaml`.
- Playnite theme docs: https://api.playnite.link/docs/tutorials/themes/introduction.html (markdown source: https://codeberg.org/Playnite/Docs).

## Process

- Branch: work on the designated `claude/*` branch; push with `git push -u origin <branch>`.
- One Linear issue per work session; keep issues updated (project "VibeMythos", team "Hyperius").
- Don't bump `source/theme.yaml` `Version`/`ThemeApiVersion` casually — `ThemeApiVersion` is gated against Playnite's `DesktopApiVersion` (major mismatch = theme refuses to load).
- Upstream sync: Mythos ships ALL default-theme style files, so any Playnite update that changes theme files may require a diff pass (track via [Playnite#1259](https://github.com/JosefNemec/Playnite/issues/1259)).
