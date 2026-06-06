<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Mythos2.png" width="90" /><br>
# Mythos

#### Credits:
[sakasakiking](https://github.com/sakasakiking) - Creator of the Dune theme, whose work serves as the visual foundation and inspiration for Mythos.<br>
[darklinkpower](https://github.com/darklinkpower) - Legend behind the original Mythic theme, without which this project wouldn't exist.<br>
[holyCherryPerry](https://github.com/holyCherryPerry) - Valued contributor to various fixes and refinements.<br><br>
![DownloadCount](https://img.shields.io/github/downloads/bansakai/Mythos/total.svg)<br><br>
[![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Version%202/Mythos2banner.png)](https://playnite.link/addons.html#Mythos_9f42c1a7-6d8e-4b3f-b0a2-7e9c5d3f18a4)
<br>
<br>

## Installation

A. Download directly from [Playnite.](https://playnite.link/addons.html#Mythos_9f42c1a7-6d8e-4b3f-b0a2-7e9c5d3f18a4)<br><br>
B. Download the latest packaged `.pthm` theme file from [Releases](https://github.com/bansakai/Mythos/releases/latest) and open it.
<br><br>
## Core Functions & Setup
### Age Rating Banners
Mythos displays the Age Rating badge of a selected game within it's details panel. To enable them, go to `Appearance > Details View` and select Age Rating. Once enabled, mirror the following terminology in Library Manager:

North America: `ESRB E10` `ESRB E` `ESRB T` `ESRB M` `ESRB AO` `ESRB RP`<br>Pan European: `PEGI 3` `PEGI 7` `PEGI 12` `PEGI 16` `PEGI 18`<BR>Russian: `RARS 0+` `RARS 6+` `RARS 12+` `RARS 16+` `RARS 18+`

### Cover Images
By default, cover art isn't visible in Details View. Open [ThemeModifier](https://playnite.link/addons.html#playnite-thememodifier-plugin) and select `Show Cover Instead of Logo`. Additionally, ensure Cover Images are enabled in `Appearance > Details View` under `Cover Image`. Logos will be replaced by cover images when enabled.
### Game Summary
The game summary, found below the trailer, simply displays the `Synopsis` metadata for the selected title. This must be configured manually in `Game Details > Advanced > Synopsis`.
### Platform Icons
Platform icons are displayed on the bottom right of detail panels. Mythos includes a handful of commonly used platform icons, but not all of them. If a specific platform does not have an icon, find a `.png` online, drop it in `Mythos\Icons\Labels`. Name icon files according to the IDs found [here.](https://github.com/JosefNemec/Playnite/blob/master/source/Playnite/Emulation/Platforms.yaml)
### Play Button Text
For those using Playnite to open external launchers or applications, you can replace the default Launch text in `Game Details > Advanced > Play Button`.
### Sidebar
Download [Filter Presets Quick Launcher](https://playnite.link/addons.html#FilterPresetsQuickLauncher_ef9df36c-24c2-418c-8468-eed95a09d950) and navigate to the plugin's settings page to set up sidebar filters. Ensure you have the Sidebar enabled in `Main Menu > View > Sidebar.` The icons used in my screenshots can be found in `Mythos\Icons\Sidebar.`
### Steam Links Bar
![Steam Links Bar](https://github.com/bansakai/Mythos/blob/Master/Screenshots/steam_link_bar.png)<br><br>
The Steam Links Bar displays all Steam client links directly below the game's image or video banner. To use this feature, download [ThemeModifier](https://playnite.link/addons.html#playnite-thememodifier-plugin) and check `Show Steam Links Bar`.<br><br>It's recommended to use the `Official Store` metadata option to import these seamlessly. Mythos will auto-detect a valid Steam Store Page link within the first `10` links, and display the remaining links dynamically.<br><br>Additionally, you can convert all Steam web links to client links using [Link Utilities.](https://playnite.link/addons.html#LinkUtilties_f692b4bb-238d-4080-ae76-4aaefde6f7a1) <br><br>

## Required Extensions
- **Display Logos:** [ExtraMetadataLoader](https://playnite.link/addons.html#ExtraMetadataLoader_705fdbca-e1fc-4004-b839-1d040b8b4429) extension.
- **Display Videos:** [ExtraMetadataLoader](https://playnite.link/addons.html#ExtraMetadataLoader_705fdbca-e1fc-4004-b839-1d040b8b4429) extension.
<br><br>
## Recommended Extensions
- **Customize Theme:** [ThemeModifier](https://playnite.link/addons.html#playnite-thememodifier-plugin) extension. <img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/twopointo.svg" width="40" /><br>
- **Extra Features:** [ThemeExtras](https://playnite.link/addons.html#felixkmh_Extras_Plugin) extension. <img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/twopointo.svg" width="40" /><br>
- **Achievements:** [SuccessStory](https://playnite.link/addons.html#playnite-successstory-plugin) extension.
- **HowLongToBeat:** [HowLongToBeat](https://playnite.link/addons.html#playnite-howlongtobeat-plugin) extension.
- **Convert Links:** [Link Utilities](https://playnite.link/addons.html#LinkUtilties_f692b4bb-238d-4080-ae76-4aaefde6f7a1) extension.
- **Sidebar Icons:** [Filter Presets Quick Launcher](https://playnite.link/addons.html#FilterPresetsQuickLauncher_ef9df36c-24c2-418c-8468-eed95a09d950) extension.
<br><br>
## Recommended Fonts
- **Icon Font:** [Microsoft's Fluent Icons](https://aka.ms/SegoeFluentIcons). `Required for Windows 10`
- **Title Font:** [Inter Tight by Google](https://fonts.google.com/specimen/Inter+Tight). `Hardcoded`
- **Body Font:** [Inter by Google](https://fonts.google.com/specimen/Inter).
- **Monospace Font:** [Inter with Modifications for Mythos](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Inter-Mod-Regular.ttf).
<br><br>
## Additional Resources
- **Download:** [Playnite Logo Concept](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/PlayniteLogo.svg) used in Mythos 1.X.
- **Download:** [Mythos MacOS Icon](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Mythos.png) for MyDockFinder users.
- **Download:** [Playnite MacOS Icon](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Playnite.png) for MyDockFinder users.
- **Download:** [Playnite Fullscreen MacOS Icon](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Playnite%20FS.png) for MyDockFinder users.
- **Download:** [Age Rating Template](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Age%20Rating%20Template.ai) to create your own rating images.
<br><br>
## Playnite Settings
![Static Badge](https://img.shields.io/badge/Highly%20Recommended-red?style=flat)<br>

<details>
<summary><strong>⚙️ Recommended Settings</strong> - Click to Expand</summary>
<br>
   
### Appearance → General<br>
<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/Settings_General.png" width="600" /><br>
### Appearance → Advanced<br>
<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/Settings_Advanced.png" width="600" /><br>
### Appearance → Details View<br>
<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/Settings_Details.png" width="600" /><br>
### Appearance → Grid View<br>
<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/Settings_Grid.png" width="600" /><br>
### Appearance → Layout<br>
<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/Settings_Layout.png" width="600" /><br>
### Appearance → Top Panel<br>
<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/Settings_TopPanel.png" width="600" />
</details><br>

> [!NOTE]
> **Features NOT Fully Supported in Mythos:**
> - Non-English Localizations - Many locale files still need to be written to support features added by Mythos.
> - Sidebar Alignment - The sidebar will always display on the left when enabled.
> - Filter Panel Alignment - Due to the layout of the theme, the Filter Panel will always align left.
> - Game Version - This field has been repurposed to support [Play Button](https://github.com/bansakai/Mythos#custom-play-button) text.
> - Notes - This field has been repurposed to support [Synopsis](https://github.com/bansakai/Mythos#game-summary) text.
> - Draw Separators Between Panels - This feature has been disabled almost entirely.


## Showcase
![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/5.png)

![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/6.png)

![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/2.png)

![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/1.png)

