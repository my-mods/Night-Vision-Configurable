# Night Vision - Configurable

N / hold L3 for 0.6 seconds toggles the existing Radius or Fullscreen mode.
Fullscreen remains the default. The existing settings and colours are unchanged.

## Natural preview

With ordinary night vision off, press F8 during vampire gameplay to toggle a soft
central brightness enhancement. The preview uses 200% brightness, 90% size and
70% softness, with the normal night image at the edges and no activation flash.
It turns off after 60 seconds, on loading, entering a menu, becoming human,
pressing N, or applying settings. F8 can start another preview. No settings are saved.
Use SDR output. The existing menu continues to offer Radius and Fullscreen.

Requires UE4SS for Dawnwalker by Vercadi 1.3 (RC6) or later.
Dawnwalker Mod Menu 1.0.6 or later is optional for existing settings.
Ordinary feature documentation: https://github.com/my-mods/Night-Vision-Configurable

## Installation

- Vortex: Install Night-Vision-Configurable.zip through Vortex, enable it and deploy.
- Manual: Copy the archive's Dawnwalker folder into The Blood of Dawnwalker game folder, preserving the folder structure.

## Package layout

The Dawnwalker folder contains Lua files and the original Natural material/helper
container. Data contains a layout note only. Root metadata, documentation and
license files stay outside deployment through Vortex override instructions.
There is no personal settings.ini, engine-wide configuration or native DLL.

Preview activation and distinct failures use the [NightVisionConfigurable] prefix
in Dawnwalker/Binaries/Win64/ue4ss/UE4SS.log. Normal Logging remains Off by default.

Inspired by Night Vision by opogode, with permission. No assets from that mod are
redistributed. Rebel Wolves created The Blood of Dawnwalker. UE4SS provides Lua;
Dawnwalker Mod Menu by mmarcussa supplies the unchanged integration helper.
See LICENSES for the bundled helper licences.
