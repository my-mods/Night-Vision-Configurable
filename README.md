# Night Vision - Configurable

Toggle vampire night vision with **N** or by holding **L3 / the left stick for 0.6 seconds**. Release the stick between toggles. Once enabled, vision stays on until you toggle it off or return to human form. Camera changes, save loading and player replacement preserve your choice and automatically resume the effect when a vampire player and camera are ready. A new game session starts with vision off.

Choose **Night Vision Mode: Radius / Fullscreen**. Radius adds a neutral white light with a six-metre falloff around your character, without a yellow torch tint or a fullscreen exposure boost. Fullscreen retains the original whole-view effect and remains the default. **Brightness** adjusts the radius light's strength or fullscreen exposure, from -2 to 4, with -0.5 as the default. Fullscreen activation includes a brief brightness pulse; either mode uses the game's loaded focus sound when available.

**Vignette** adds a soft blood-red effect around the screen edges. It defaults to On at **20% opacity**; its **0–100% opacity slider** is visible only while Vignette is On. Off or 0% removes the overlay. This is independent of the game's damage effects.

**Black & White monochrome** blends from natural colours at **0%** to black and white at **100%**. **Red monochrome** blends toward a fully red monochrome view at **100%**. Both default to **0%**, use **5% steps**, and work in either mode. They can be combined: Black & White removes colour, while Red also adds a red tint. The vignette stays red independently of these sliders.

Turning vision off removes its light and overlay and restores camera values still owned by the mod. With Red monochrome at 0%, the original scene tint is preserved. No chromatic aberration is added. If another game effect resets the camera settings, night vision restores its appearance and remembers those new values for when you turn it off. Controller input is blocked while paused, while the mouse cursor is visible, or while movement input is disabled; these restrictions do not turn active vision off.

## Dependencies

A Dawnwalker-compatible UE4SS installation providing Lua 5.4, game-thread delayed actions, cancellation and native function hooks. Dawnwalker Mod Menu **1.0.6 or later** is optional for the settings page and live Apply; its console bridge needs `HookProcessConsoleExec=1` in the UE4SS profile.

## Installation

- Vortex: Install `Night-Vision-Configurable.zip` through Vortex, enable it and deploy.
- Manual: Copy the archive's `Data/NightVisionConfigurable` folder into `<The Blood of Dawnwalker>/Dawnwalker/Binaries/Win64/ue4ss/Mods`, preserving the folder structure.

## Configuration

Open **Mod Settings > Night Vision - Configurable**. Apply saves changes and adjusts active vision immediately. Enabled controls whether the mod is available; switching it Off also turns vision off. Enabling it again does not automatically activate vision. The controller shortcut can be disabled independently of keyboard N.

Without the menu, edit `NightVisionConfigurable/settings.ini`, generated on first launch, and restart the game. `settings.ini.example` documents the defaults. The archive does not include a personal settings file. Existing brightness and monochrome preferences remain in use; new keys take their defaults until saved through Apply.

**Logging** is the final setting and defaults to Off. When enabled, activation/readiness messages, selected appearance values, camera-repair counts and aggregate input/vision-check timings appear in `Dawnwalker/Binaries/Win64/ue4ss/UE4SS.log` with the `[NightVisionConfigurable]` prefix. Distinct failures are reported once. The mod never polls configuration files or writes unchanged camera settings. The controller shortcut checks cached player input every 50 ms. While vision is enabled, camera values and owned effect validity are checked every 250 ms; keyboard-only mode also checks camera/form ownership at that interval and stops after deactivation. The light follows its attachment without scripted movement updates. Unsupported operations are suspended separately with bounded retries, preserving other available effects.

## Source and packaging

The Lua sources are in `src`. To assemble a package, copy those files into `Data/NightVisionConfigurable/Scripts`, and put `package/enabled.txt` and `package/mod_settings.ini` in `Data/NightVisionConfigurable`. Put `package/mod.manifest` at archive root, alongside a UTF-8 `README.txt` made from this README and the license files. The pinned common modules and unchanged menu helper are already bundled; no compiler or separate common-library installation is required.

Keep the `Nexus` release materials, changelog, release notes and provenance files at archive root, outside `Data`.

## Credits

Inspired by [Night Vision by opogode](https://www.nexusmods.com/thebloodofdawnwalker/mods/294), made with permission. This independent implementation does not redistribute that mod's script or assets. Rebel Wolves created The Blood of Dawnwalker. UE4SS provides the Lua runtime. Dawnwalker Mod Menu by mmarcussa provides the settings UI and its unchanged integration helper, copied as directed by its integration guide. The bundled [ue4ss-common](https://github.com/my-mods/ue4ss-common) settings modules are MIT licensed; see `LICENSES/ue4ss-common.txt`.

The banner and thumbnail use an official Rebel Wolves gameplay screenshot with permission. See `Nexus/MEDIA-CREDITS.md` for the source and image rights.
