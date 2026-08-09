# UniPlaySong top panel integration — design

Date: 2026-08-09
Issues: HYP-192 (foundation), HYP-159 (UniPlaySong)
Branch: `alessandrocaetanob/hyp-192-top-panel-remove-debug-colors-and-fixed-sizing-that-break`

## Problem

The music controls in the Playnite top panel render badly: cramped icons, a
truncated track title, and an out-of-place amber block.

The initial framing — "the UniPlaySong integration is ugly" — turned out to be
wrong in an important way. **The theme has no UniPlaySong integration at all.**
No `UPS_*` control is declared anywhere in `source/`. What is on screen is the
plugin's own top panel items being mangled by the theme.

## Root cause

UniPlaySong registers four Desktop-only top panel items in
`src/DeskMediaControl/TopPanelMediaControlViewModel.cs`:

| Field | On screen |
|---|---|
| `_playPauseItem` | pause button |
| `_skipItem` | skip button |
| `_nowPlayingItem` | "· Assa…" track label |
| `_spectrumItem` | amber bar visualizer |

Playnite injects these into `PART_PanelMainPluginItems` (`Views/TopPanel.xaml:522`),
where they pick up the theme's `TopPanelItem` style. That style carried three
defects inherited from upstream Mythos:

1. `Width="35" Height="35"` hardcoded — non-square items are crushed and overflow.
2. An implicit `TextBlock` style setting `Foreground="Red"` inside the `ContentPresenter`.
3. A null-content `MultiTrigger` painting the item `OrangeRed`.

`CustomControls/SidebarItem.xaml:109` carried the same `OrangeRed` marker.

Corroboration from the plugin side: UniPlaySong's own repair notes say it trims
item margins "without overriding other theme styling (**MinWidth**, Padding,
Background)" — it expects themes to size with `MinWidth`. Mythos hardcoded `Width`.

## Constraint that shaped the design

The obvious idea — build a bespoke Mythos-styled transport pill from
`{PluginSettings}` bindings and `playnite://uniplaysong/*` URIs — does not work.

The theme cannot remove plugin-registered top panel items, and only the spectrum
has a settings gate (`_spectrumItem.Visible = settings?.ShowSpectrumVisualizer`).
Play/pause, skip and now-playing have no off switch. A custom pill would appear
*alongside* the plugin's four items, not replace them, leaving two sets of
transport controls.

The plugin's theme guide states the same limitation from the other direction:
"Playnite can't inject theme XAML into a plugin control."

So the fix is not to build something better next to the plugin's controls. It is
to stop the theme from breaking what the plugin already provides, then add a
surface that cannot duplicate them.

## Design

### Part 1 — Foundation (`CustomControls/TopPanelItem.xaml`)

- `Width="35"` → `MinWidth="35"`, plus `MaxWidth="240"` so a long track title
  cannot blow out the centre cluster. `Height="35"` stays fixed for pill-row
  alignment.
- `Padding="8,0"` so text items do not touch the pill edge. Icon items are
  unaffected: a 16px glyph in a 35px box.
- The `Foreground="Red"` implicit style becomes `{DynamicResource TextBrush}`,
  with `VerticalAlignment="Center"` and `TextTrimming="CharacterEllipsis"`.
- The null-content `OrangeRed` `MultiTrigger` is deleted, here and in
  `SidebarItem.xaml`.

`DefaultControls/DataGrid.xaml:113` also uses red, but as a legitimate
validation-error indicator. Left alone.

This benefits every plugin that injects a non-icon top panel item, so HYP-192
is marked as blocking HYP-157, HYP-158, HYP-159, HYP-160 and HYP-161.

### Part 2 — Now Playing toast (`Views/MainWindow.xaml`)

A `Border` appended to the outer `Grid` after `PART_Notifications`, so it paints
on top. Album art, title and artist read from `{PluginSettings Plugin=UniPlaySong}`,
wearing `GlassControlBrushDark` / `ContentBorderBrushOverlay` /
`ControlCornerRadiusLarge` so it reads as part of Mythos.

Behaviour: a `DataTrigger` on `IsMusicChanged` runs a storyboard that slides and
fades the toast in over 0.25s, holds 4.5s, then slides and fades out over 0.5s.

Three decisions worth recording:

- **No `PluginStatus` gate.** `{PluginSettings}` no-ops when the plugin is
  absent, so `IsMusicChanged` never pulses and the toast stays at `Opacity="0"`.
  Safe to ship unconditionally, and it avoids depending on a UniPlaySong AddonId
  that is not documented.
- **The storyboard animates `RenderTransform.X` by property path, and the
  `TranslateTransform` is deliberately unnamed.** A `Storyboard` inside a `Style`
  may not use `Storyboard.TargetName` — WPF throws and Playnite crashes.
- **Top-right placement is safe.** `PART_Notifications` is
  `HorizontalAlignment="Center"`, so it drops from top-centre and cannot collide.
  `IsHitTestVisible="False"` keeps the toast from swallowing clicks on the grid.

### Part 3 — Toggle and strings

- `Constants.xaml`: `ShowNowPlayingToast` (default `True`), consumed via
  `DynamicResource` per the ThemeModifier hard rule.
- `thememodifier.yaml`: new `"Music"` section header plus the entry.
- `Localization/en_US.xaml`: `LOCMythos_NowPlaying`, theme-prefixed so it does
  not leak into Playnite's global namespace — the mistake HYP-166 exists to fix.

## Out of scope

Deferred to their own sessions, all independent of the visual problem:
music/trailer coexistence via `UPS_MusicControl` (HYP-159 task 2), theme-shipped
`UPS_BackgroundAudio` (task 4), and per-rarity achievement jingles.

## Verification

Automated, all passing:

- every `source/**/*.xaml` parses as XML;
- all 37 `thememodifier.yaml` entries resolve against `Constants.xaml` or
  `Localization/en_US.xaml`;
- `en_US.xaml` contains only `sys:String` entries (38 keys).

Not yet verified: visual behaviour. Playnite is Windows-only and is not installed
in this environment, so the toast animation, the corrected item sizing, and
whether UniPlaySong's own text was actually hitting the red style all need
confirmation by deploying to `%AppData%\Playnite\Themes\Desktop\` and restarting.
