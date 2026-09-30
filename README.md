# Night Vision - Configurable

Toggle vampire night vision with **N** or by holding **L3 / the left stick for 0.6 seconds**. Release the stick between toggles. Vision starts off and resets after loading, possession changes, a camera change or a return to human form.

Natural colours are the default. **Monochrome amount** runs from **0% natural colours** to **100% black and white** in **5% steps**. **Brightness** adjusts exposure independently, from -2 to 4, with -0.5 as the default. Activation includes a brief brightness pulse and uses the game's loaded focus sound when available.

The effect changes the current player camera only. It preserves the scene's colour tint and avoids adding chromatic aberration. Turning it off restores camera values still owned by the mod. Controller input is blocked while paused, while the mouse cursor is visible, or while movement input is disabled.

## Dependencies

A Dawnwalker-compatible UE4SS installation providing Lua 5.4, game-thread delayed actions, cancellation and native function hooks. Dawnwalker Mod Menu **1.0.6 or later** is optional for the settings page and live Apply; its console bridge needs `HookProcessConsoleExec=1` in the UE4SS profile.

## Installation

- Vortex: Install `Night-Vision-Configurable.zip` through Vortex, enable it and deploy.
- Manual: Copy the archive's `Data/NightVisionConfigurable` folder into `<The Blood of Dawnwalker>/Dawnwalker/Binaries/Win64/ue4ss/Mods`, preserving the folder structure.

## Configuration

Open **Mod Settings > Night Vision - Configurable**. Apply saves changes and adjusts active vision immediately. Enabled controls whether the shortcuts are available; it does not automatically turn vision on. The controller shortcut can be disabled independently of keyboard N.

Without the menu, edit `NightVisionConfigurable/settings.ini`, generated on first launch, and restart the game. `settings.ini.example` documents the defaults. The archive does not include a personal settings file.

**Logging** is the final setting and defaults to Off. When enabled, activation/readiness messages and aggregate input-check timings appear in `Dawnwalker/Binaries/Win64/ue4ss/UE4SS.log` with the `[NightVisionConfigurable]` prefix. Distinct failures are reported once. The mod never polls configuration files or reapplies unchanged settings. The controller shortcut checks cached player input every 50 ms; keyboard-only active vision checks camera/form ownership every 250 ms and stops after deactivation.

## Source and packaging

The Lua sources are in `src`. To assemble a package, copy those files into `Data/NightVisionConfigurable/Scripts`, and put `package/enabled.txt` and `package/mod_settings.ini` in `Data/NightVisionConfigurable`. Put `package/mod.manifest` at archive root, alongside a UTF-8 `README.txt` made from this README and the license files. The pinned common modules and unchanged menu helper are already bundled; no compiler or separate common-library installation is required.

Keep the `Nexus` release materials, changelog, release notes and provenance files at archive root, outside `Data`.

## Credits

Inspired by [Night Vision by opogode](https://www.nexusmods.com/thebloodofdawnwalker/mods/294), made with permission. This independent implementation does not redistribute that mod's script or assets. Rebel Wolves created The Blood of Dawnwalker. UE4SS provides the Lua runtime. Dawnwalker Mod Menu by mmarcussa provides the settings UI and its unchanged integration helper, copied as directed by its integration guide. The bundled [ue4ss-common](https://github.com/my-mods/ue4ss-common) settings modules are MIT licensed; see `LICENSES/ue4ss-common.txt`.

The banner and thumbnail use an official Rebel Wolves gameplay screenshot with permission. See `Nexus/MEDIA-CREDITS.md` for the source and image rights.
