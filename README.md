<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Logo.png" width="90" /><br>
# Mythos

#### Credits:
[sakasakiking](https://github.com/sakasakiking) - Creator of the Dune theme, whose work served as the visual foundation and inspiration for Mythos.<br>
[darklinkpower](https://github.com/darklinkpower) - Legend behind the original Mythic theme, without which this project wouldn't exist.<br>
[holyCherryPerry](https://github.com/holyCherryPerry) - Valued contributor to various fixes and refinements.<br><br>
![DownloadCount](https://img.shields.io/github/downloads/bansakai/Mythos/total.svg)<br><br>
![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/4.png)
<br>
<br>

## Installation

A. Download directly from [Playnite.](https://playnite.link/addons.html#Mythos_9f42c1a7-6d8e-4b3f-b0a2-7e9c5d3f18a4)<br><br>
B. Download the latest packaged `.pthm` theme file from [Releases](https://github.com/bansakai/Mythos/releases/latest) and open it.
<br><br>
## Theme Functions & Setup
### Age Ratings
In Details View, Mythos will display the ESRB or PEGI rating of the selected game underneath the logo. For age ratings to work, your Playnite rating configuration needs to mirror the following:

 North America:  `ESRB E10` `ESRB E` `ESRB T` `ESRB M` `ESRB AO` `ESRB RP`<br>Europe: `PEGI 3` `PEGI 7` `PEGI 12` `PEGI 16` `PEGI 18`

### Cover Images
By default, cover images aren't enabled. Head to `Appearance > Details View` and check `Cover Image.` Covers will replace logos in Details View.
### Custom Play Button
If you're someone like me who uses Playnite to open external launchers or applications, you can enter custom Play button text under the `Version` metadata of your game, and that will be shown instead. By default, the Play button is labeled "Launch."
### Game Summary
The synopsis portion, below the trailer, simply displays the `Notes` metadata for a selected title. Unfortunately, this must be configured manually. I intended to write an automated solution for this, but it extended a bit beyond the scope of this project.
### Platform Icons
If enabled, platform icons are displayed on the bottom right of Details View. I've included a handful of commonly used platform icons, but not nearly enough to cover all of them. If a specific platform does not have an icon, find a `.png` online, drop it in `Mythos\Icons\Labels,` and name the file accordingly.
### Sidebar
Download [Filter Presets Quick Launcher](https://playnite.link/addons.html#FilterPresetsQuickLauncher_ef9df36c-24c2-418c-8468-eed95a09d950) and navigate to the plugin's settings page to set up sidebar filters. Ensure you have Sidebar Left enabled in `Main Menu > View > Sidebar.` The icons used in my screenshots can be found in `Mythos\Icons\Sidebar.`
### Steam Links Bar
Mythos introduces what I'm calling the "Steam Links Bar," which elegantly displays all Steam client links directly below the game's video banner. To use this feature correctly, your Steam links should be imported before all other links. Make sure to use the **Official Store** metadata option to import these easily.<br><br> Alternatively, ensure you have a **Steam Community Hub** link and move it up to one of the first six slots. Mythos will auto-detect Steam Links from that point. From there, you can convert all Steam web links to client links using [Link Utilities.](https://playnite.link/addons.html#LinkUtilties_f692b4bb-238d-4080-ae76-4aaefde6f7a1) <br><br>
![Steam Links Bar](https://github.com/bansakai/Mythos/blob/Master/Screenshots/steam_link_bar.png)
<br><br>

## Required Extensions
- **Display Logos:** [ExtraMetadataLoader](https://playnite.link/addons.html#ExtraMetadataLoader_705fdbca-e1fc-4004-b839-1d040b8b4429) extension.
- **Display Videos:** [ExtraMetadataLoader](https://playnite.link/addons.html#ExtraMetadataLoader_705fdbca-e1fc-4004-b839-1d040b8b4429) extension.
<br><br>
## Supported Extensions
- **Customize Theme:** [ThemeModifier](https://playnite.link/addons.html#playnite-thememodifier-plugin) extension. ![New Badge](https://img.shields.io/badge/2.0-0379ff)
- **Additional Theme Features:** [ThemeExtras](https://playnite.link/addons.html#felixkmh_Extras_Plugin) extension. ![New Badge](https://img.shields.io/badge/2.0-0379ff)
- **HowLongToBeat Support:** [HowLongToBeat](https://playnite.link/addons.html#playnite-howlongtobeat-plugin) extension.
- **Achievements Support:** [SuccessStory](https://playnite.link/addons.html#playnite-successstory-plugin) extension.
<br><br>
## Recommended Fonts
- **Application Font:** [Inter by Google](https://fonts.google.com/specimen/Inter).
- **Monospaced Font:** [Inter with Modifications for Mythos](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Inter-Mod-Regular.ttf).
- **Icon Font:** [Microsoft's MDL2 Icons](https://aka.ms/SegoeFonts). `Required for Windows 10`
<br><br>
## Additional Resources
- **Download:** [Playnite Logo Concept](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/PlayniteLogo.svg) used in Mythos.
- **Download:** [Mythos MacOS Icon](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Mythos.png) for MyDockFinder users.
- **Download:** [Playnite MacOS Icon](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Playnite.png) for MyDockFinder users.
- **Download:** [Playnite Fullscreen MacOS Icon](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Playnite%20FS.png) for MyDockFinder users.
- **Download:** [Age Rating Template](https://raw.githubusercontent.com/bansakai/Mythos/Master/Resources/Age%20Rating%20Template.ai) to create your own rating images.
<br><br>
## Playnite Settings
![Static Badge](https://img.shields.io/badge/Highly%20Recommended-red?style=flat)<br>

<details>
<summary>Expand - All settings used in the showcase:</summary>
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
<img src="https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/SettingsTopPanel.png" width="600" />
</details><br>


## Showcase
![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/5.png)

![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/6.png)

![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/2.png)

![Screenshot](https://raw.githubusercontent.com/bansakai/Mythos/Master/Screenshots/1.png)

