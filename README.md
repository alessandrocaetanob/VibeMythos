<img src="https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Resources/Mythos2.png" width="90" /><br>
# VibeMythos

A fork of [Mythos](https://github.com/bansakai/Mythos) by [bansakai](https://github.com/bansakai) — a Fluent UI–inspired desktop theme for [Playnite](https://playnite.link). VibeMythos builds on Mythos 2.0 with bundled typography, deeper plugin integrations, and an ongoing push toward a more cinematic library. See [the 3.0 plan](docs/vibemythos-3.0-plan.md) for where it's headed.

#### Credits:
[bansakai](https://github.com/bansakai) - Creator of Mythos, which this theme is forked from and built on.<br>
[sakasakiking](https://github.com/sakasakiking) - Creator of the Dune theme, whose work serves as the visual foundation and inspiration for Mythos.<br>
[darklinkpower](https://github.com/darklinkpower) - Legend behind the original Mythic theme, without which this project wouldn't exist.<br>
[holyCherryPerry](https://github.com/holyCherryPerry) - Valued contributor to various fixes and refinements.<br>
[yabo-san](https://github.com/yabo-san) - GPU-accelerated Grid View scrolling.<br><br>
[![Screenshot](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Resources/Version%202/Mythos2banner.png)](https://github.com/alessandrocaetanob/VibeMythos)
<br>
<br>

## Installation

> [!WARNING]
> **No packaged release exists yet.** Until one is published, install from source: copy the
> contents of `source/` into a folder under your Playnite themes directory named
> `VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca`, then pick VibeMythos in
> `Settings → Appearance`.
>
> ```powershell
> $dest = "<PlayniteInstall>\Themes\Desktop\VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca"
> New-Item -ItemType Directory -Force $dest
> Copy-Item source\* $dest -Recurse -Force
> ```

Once releases exist, the packaged `.pthm` from
[Releases](https://github.com/alessandrocaetanob/VibeMythos/releases/latest) can be opened directly.

> [!NOTE]
> VibeMythos is **not** in Playnite's addon browser, and it uses its own theme `Id` — separate
> from upstream Mythos. That means the two can be installed side by side, and Playnite will never
> offer an upstream Mythos release as an "update" to this fork.
>
> **Playnite wipes the theme folder before extracting, on every install and update.** VibeMythos
> asks [ThemeExtras](https://playnite.link/addons.html#felixkmh_Extras_Plugin) to restore the
> folders you're meant to add your own files to — `Images/Banners`, `Icons/Labels`, `Icons/Sidebar`,
> `Icons/Platform Source` and `audio` — so those survive an update.
>
> **This only works with ThemeExtras installed.** Without it, and for anything outside those five
> folders, your files are gone. Back up anything you can't easily recreate.
<br><br>
## Core Functions & Setup
### Age Rating Banners
VibeMythos displays the Age Rating badge of a selected game within it's details panel. To enable them, go to `Appearance > Details View` and select Age Rating. Once enabled, mirror the following terminology in Library Manager:

North America: `ESRB E10` `ESRB E` `ESRB T` `ESRB M` `ESRB AO` `ESRB RP`<br>Pan European: `PEGI 3` `PEGI 7` `PEGI 12` `PEGI 16` `PEGI 18`<BR>Russian: `RARS 0+` `RARS 6+` `RARS 12+` `RARS 16+` `RARS 18+`

### Cover Images
By default, cover art isn't visible in Details View. Open [ThemeModifier](https://playnite.link/addons.html#playnite-thememodifier-plugin) and select `Show Cover Instead of Logo`. Additionally, ensure Cover Images are enabled in `Appearance > Details View` under `Cover Image`. Logos will be replaced by cover images when enabled.
### Game Summary
The game summary, found below the trailer, simply displays the `Synopsis` metadata for the selected title. This must be configured manually in `Game Details > Advanced > Synopsis`.
### Platform Icons
Platform icons are displayed on the bottom right of detail panels. VibeMythos includes a handful of commonly used platform icons, but not all of them. If a specific platform does not have an icon, find a `.png` online, drop it in `<PlayniteInstall>\Themes\Desktop\VibeMythos_fb4d738f-62bd-4e08-afd9-52e8cb45f6ca\Icons\Labels`. Name icon files according to the IDs found [here.](https://github.com/JosefNemec/Playnite/blob/master/source/Playnite/Emulation/Platforms.yaml)<br><br>Library **source** icons (Steam, GOG, Epic…) work the same way but live in `Icons\Platform Source`, named after the library's source name. Both folders are preserved across theme updates when ThemeExtras is installed.
### Play Button Text
For those using Playnite to open external launchers or applications, you can replace the default Launch text in `Game Details > Advanced > Play Button`.
### Sidebar
Download [Filter Presets Quick Launcher](https://playnite.link/addons.html#FilterPresetsQuickLauncher_ef9df36c-24c2-418c-8468-eed95a09d950) and navigate to the plugin's settings page to set up sidebar filters. Ensure you have the Sidebar enabled in `Main Menu > View > Sidebar.` The icons used in my screenshots can be found in the theme's `Icons\Sidebar` folder.
### Steam Links Bar
![Steam Links Bar](https://github.com/alessandrocaetanob/VibeMythos/blob/Master/Screenshots/steam_link_bar.png)<br><br>
The Steam Links Bar displays all Steam client links directly below the game's image or video banner. To use this feature, download [ThemeModifier](https://playnite.link/addons.html#playnite-thememodifier-plugin) and check `Show Steam Links Bar`.<br><br>It's recommended to use the `Official Store` metadata option to import these seamlessly. VibeMythos will auto-detect a valid Steam Store Page link within the first `10` links, and display the remaining links dynamically.<br><br>Additionally, you can convert all Steam web links to client links using [Link Utilities.](https://playnite.link/addons.html#LinkUtilties_f692b4bb-238d-4080-ae76-4aaefde6f7a1) <br><br>

## Plugin Pairing Guide

Every integration below is **optional except ExtraMetadataLoader** — each block collapses on its
own when its plugin is absent, so the theme never leaves an empty husk behind.

| Plugin | Lights up |
| --- | --- |
| **[ExtraMetadataLoader](https://playnite.link/addons.html#ExtraMetadataLoader_705fdbca-e1fc-4004-b839-1d040b8b4429)** `required` | Game logos in Details View and Grid View, and the video banner in Details View. Without it, the logo slot falls back to the game icon. |
| **[ThemeModifier](https://playnite.link/addons.html#playnite-thememodifier-plugin)** | 41 theme settings — accent colours, floating sidebar, Steam Links Bar, ambient backdrop reach, Grid View toggles. This is how you customise the theme. |
| **[ThemeExtras](https://playnite.link/addons.html#felixkmh_Extras_Plugin)** | Navigation buttons in the top panel, and library banners on grid covers. Also **preserves your custom icons and audio across theme updates** — see the install note above. |
| **[Playnite Achievements](https://github.com/justin-delano/PlayniteAchievements)** | The achievements row in Details View, the Grid View progress readout, and the gold completion state at 100%. |
| **[SuccessStory](https://playnite.link/addons.html#playnite-successstory-plugin)** | The achievements row in Details View only. The two plugins are mutually exclusive by design — with SuccessStory installed the Playnite Achievements blocks self-collapse, so the Grid View readout and gold 100% state are Playnite Achievements only. |
| **[HowLongToBeat](https://playnite.link/addons.html#playnite-howlongtobeat-plugin)** | The Main Story / Main + Extra / Completionist estimate row above the metadata panel. |
| **[DuplicateHider](https://playnite.link/addons.html#felixkmh_DuplicateHider_Plugin)** | Library source badges (Steam, GOG, Epic, Xbox…) on grid covers, in the Details View **Library row**, and in the Grid View details panel. |
| **[UniPlaySong](https://github.com/aHuddini/UniPlaySong)** | The Now Playing toast. (A themed top-panel transport is designed but not yet shipped.) |
| **[Link Utilities](https://playnite.link/addons.html#LinkUtilties_f692b4bb-238d-4080-ae76-4aaefde6f7a1)** | Converts Steam web links to client links so the Steam Links Bar opens in-app. |
| **[Filter Presets Quick Launcher](https://playnite.link/addons.html#FilterPresetsQuickLauncher_ef9df36c-24c2-418c-8468-eed95a09d950)** | Sidebar filter entries. No dedicated wiring — it inherits the theme's generic `SidebarItem` styling like any sidebar plugin. |
<br>
## Fonts
The theme **ships its own text fonts** in `Typefaces/` — Inter Tight for titles, Inter for body
text, and the Mythos-modified Inter for the description and notes. The icon font is the one
exception and still comes from the system:

- **Icon Font:** [Microsoft's Fluent Icons](https://aka.ms/SegoeFluentIcons). `Required for Windows 10`
  — with `Segoe MDL2 Assets` as the Windows 10 fallback.

> [!IMPORTANT]
> **The bundled fonts only load on a portable Playnite install.** Font paths resolve against
> Playnite's own program directory. A portable install keeps themes there; a standard install
> puts them in `%AppData%\Playnite\Themes\Desktop\`, where the bundled files are out of reach.
> This is decided purely by which kind of Playnite you run — **the install method makes no
> difference**, since Playnite routes both the addon browser and a double-clicked `.pthm` to the
> same location. Nothing breaks — each family falls back to the system-installed face — but you
> get plain Inter everywhere instead of three distinct faces.
>
> **How to tell:** if game titles and body text look like the same font, the bundled files did not
> resolve. To get the intended look on a standard install, install the fonts yourself:
> [Inter](https://fonts.google.com/specimen/Inter),
> [Inter Tight](https://fonts.google.com/specimen/Inter+Tight), and
> [Inter Mod](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/source/Typefaces/Inter-Mod-Regular.ttf)
> (the Mythos-modified Inter, not available from Google Fonts).

**Font licensing:** the bundled fonts are **not** covered by this repository's MIT `LICENSE`.
Inter and Inter Tight are licensed under the SIL Open Font License 1.1 — see
`Typefaces/OFL-Inter.txt` and `Typefaces/OFL-InterTight.txt`. `Inter-Mod-Regular.ttf` is a
modification of Inter and is covered by the same OFL terms.
<br><br>
## Additional Resources
- **Download:** [Playnite Logo Concept](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Resources/PlayniteLogo.svg) used in Mythos 1.X.
- **Download:** [Mythos MacOS Icon](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Resources/Mythos.png) for MyDockFinder users.
- **Download:** [Playnite MacOS Icon](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Resources/Playnite.png) for MyDockFinder users.
- **Download:** [Playnite Fullscreen MacOS Icon](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Resources/Playnite%20FS.png) for MyDockFinder users.
- **Download:** [Age Rating Template](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Resources/Age%20Rating%20Template.ai) to create your own rating images.
<br><br>
## Playnite Settings
![Static Badge](https://img.shields.io/badge/Highly%20Recommended-red?style=flat)<br>

<details>
<summary><strong>⚙️ Recommended Settings</strong> - Click to Expand</summary>
<br>
   
### Appearance → General<br>
<img src="https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/Settings_General.png" width="600" /><br>
### Appearance → Advanced<br>
<img src="https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/Settings_Advanced.png" width="600" /><br>
### Appearance → Details View<br>
<img src="https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/Settings_Details.png" width="600" /><br>
### Appearance → Grid View<br>
<img src="https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/Settings_Grid.png" width="600" /><br>
### Appearance → Layout<br>
<img src="https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/Settings_Layout.png" width="600" /><br>
### Appearance → Top Panel<br>
<img src="https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/Settings_TopPanel.png" width="600" />
</details><br>

> [!NOTE]
> **Features NOT Fully Supported in VibeMythos:**
> - Non-English Localizations - Many locale files still need to be written to support features added by the theme.
> - Sidebar Alignment - The sidebar will always display on the left when enabled.
> - Filter Panel Alignment - Due to the layout of the theme, the Filter Panel will always align left.
> - Game Version - This field has been repurposed to support [Play Button](#play-button-text) text.
> - Notes - This field has been repurposed to support [Synopsis](#game-summary) text.
> - Draw Separators Between Panels - This feature has been disabled almost entirely.


## Showcase
![Screenshot](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/5.png)

![Screenshot](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/6.png)

![Screenshot](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/2.png)

![Screenshot](https://raw.githubusercontent.com/alessandrocaetanob/VibeMythos/Master/Screenshots/1.png)

