# Night Vision - Configurable

Toggle vampire night vision with **N** or by holding **L3 / the left stick for 0.6 seconds**. Release the stick between toggles. Once enabled, vision stays on until you toggle it off or return to human form. Camera changes, save loading and player replacement preserve your choice and automatically resume the effect when a vampire player and camera are ready. A new game session starts with vision off.

Choose **Night Vision Mode: Radius / Fullscreen**. Radius lights the area around your character like a white torch. Its **Light radius** slider appears only in Radius mode: **5–50 metres**, in **1-metre steps**, default **6 metres**. Fullscreen brightens the whole view and remains the default.

The current development archive also includes an optional **Natural preview**. With ordinary night vision off, press **F8** during vampire gameplay to brighten a broad oval around the camera aim while preserving the normal night image at the edges. The preview uses 200% brightness, 90% size and 70% softness, with no activation flash. F8 turns it off; it also ends after 60 seconds, on menus/loading, becoming human, pressing N or applying settings. Use SDR output. The settings menu still offers Radius and Fullscreen.

**Brightness** runs from **25% to 300%**, in **5% steps**, default **200%**. In Fullscreen mode, 100% keeps normal game brightness; higher values brighten the view without forcing extra bloom or changing exposure. In Radius mode, 100% is the light's standard strength. The game's lighting and display settings still affect the result. Fullscreen activation includes a brief brightness pulse; either mode uses the game's loaded focus sound when available.

**Vignette** reuses the game's vampire blood-hunger texture: irregular red veins fade softly inward from the edges. It uses its own overlay and does not trigger hunger or low-health effects. It defaults to On at **20% opacity**. Its **0–100% slider**, in **5% steps**, appears only when On. Off or 0% removes the border. It is independent of the game's damage effects.

**Black & White** removes colour from the world: **0%** keeps natural colours; **100%** is black and white. **Red tint** colours only the added light in Radius mode, so unlit areas keep their colours. In Fullscreen mode, it colours the whole view. Both use **0–100%**, in **5% steps**, default **0%**. The vignette stays red independently.

**Keep blood red** is an optional toggle under Black & White, default **Off**. On preserves red shades while the slider removes other colours, so blood and the vampire vignette can stay red together. It also preserves similarly red clothing and objects. Dark or discoloured blood may lose some colour, and lighting still affects the result. Use it with **HDR output off**. With HDR enabled, an unavailable filter or another camera colour filter taking priority, ordinary Black & White remains active and the vignette stays red.

**Red brightness** appears when Keep blood red is On. It runs from **100% to 500% in 10% steps**, default **100%** for the original brightness. Higher values brighten preserved reds in the world, including other red objects. The Black & White slider controls how strongly this colour filter is applied; already bright reds can reach the display's brightness limit. The vampire border has separate controls. Turning Keep blood red Off hides the slider and retains its saved value.

Menus temporarily hide the light, border and camera effects; returning to gameplay restores them without another toggle. Pausing, showing the mouse cursor, blocking movement or hiding gameplay UI also suspends the effects and shortcuts. Turning vision off removes its light and border and restores camera values still owned by the mod. No chromatic aberration is added. Changes made by other game effects are preserved when night vision ends.

## Dependencies

Requires [UE4SS for Dawnwalker by Vercadi](https://www.nexusmods.com/thebloodofdawnwalker/mods/18) **1.3 (RC6) or later**, providing Lua 5.4, game-thread delayed actions, cancellation and native function hooks. Dawnwalker Mod Menu **1.0.6 or later** is optional for the settings page and live Apply; its console bridge needs `HookProcessConsoleExec=1` in the UE4SS profile.

## Installation

- Vortex: Install `Night-Vision-Configurable.zip` through Vortex, enable it and deploy.
- Manual: Copy the archive's `Dawnwalker` folder into The Blood of Dawnwalker's game folder, preserving the folder structure.

## Configuration

Open **Mod Settings > Night Vision - Configurable**. Apply saves changes and adjusts active vision immediately. Enabled controls whether the mod is available; switching it Off also turns vision off. Enabling it again does not automatically activate vision. The controller shortcut can be disabled independently of keyboard N.

Without the menu, edit `NightVisionConfigurable/settings.ini`, generated on first launch, and restart the game. `settings.ini.example` documents the defaults. The archive does not include a personal settings file. On startup, missing settings are added to the INI before the menu opens, preserving existing values, comments and unrelated sections. The first upgrade keeps the original file as `settings.ini.before-upgrade`; an existing backup is never overwritten. The old brightness value is converted to the nearest available percentage, limited to 25–300%; its original line is retained. Because Fullscreen no longer forces exposure and bloom, the previous look may need a brightness adjustment.

**Logging** is the final setting and defaults to Off. When enabled, activation/readiness messages, selected appearance values, camera-repair counts and aggregate input/vision-check timings appear in `Dawnwalker/Binaries/Win64/ue4ss/UE4SS.log` with the `[NightVisionConfigurable]` prefix. Distinct failures are reported once. The mod never polls configuration files or writes unchanged camera settings. The controller shortcut checks cached player input every 50 ms. While vision is enabled, camera values and owned effect validity are checked every 250 ms; keyboard-only mode also checks camera/form ownership at that interval and stops after deactivation. The light follows its attachment without scripted movement updates. Unsupported operations are suspended separately with bounded retries, preserving other available effects.

## Source and packaging

The Lua sources are in `src`. For the current development package, copy those files into `Dawnwalker/Binaries/Win64/ue4ss/Mods/NightVisionConfigurable/Scripts`, replacing `main.lua` with `preview/main.lua`. Copy all PNG files from `assets` into that mod's `Textures` folder, and put `package/enabled.txt` and `package/mod_settings.ini` at the mod root. The pinned common modules and unchanged menu helper are already bundled.

The [Natural prototype](Unreal/README.md) supplies the original Unreal 5.5.4 material/Blueprint assets and cooking details. Put its cooked container in `Dawnwalker/Content/Paks/~mods`. The existing `src/main.lua` remains the two-mode entry point; the development archive uses `preview/main.lua` to add the F8 test without adding a menu mode.

Put `package/mod.manifest`, `preview/README.txt`, `preview/vortex_override_instructions.json` and the license files at archive root. Copy `preview/NightVisionConfigurable-Layout.txt` into `Data`; it is a layout note, not runtime payload. Keep the `Nexus` release materials, changelog, release notes and provenance files at archive root, outside the `Dawnwalker` runtime folder.

## Credits

Inspired by [Night Vision by opogode](https://www.nexusmods.com/thebloodofdawnwalker/mods/294), made with permission. This independent implementation does not redistribute that mod's script or assets. Rebel Wolves created The Blood of Dawnwalker. UE4SS provides the Lua runtime. Dawnwalker Mod Menu by mmarcussa provides the settings UI and its unchanged integration helper, copied as directed by its integration guide. The bundled [ue4ss-common](https://github.com/my-mods/ue4ss-common) settings modules are MIT licensed; see `LICENSES/ue4ss-common.txt`.

The banner and thumbnail use an official Rebel Wolves gameplay screenshot with permission. See `Nexus/MEDIA-CREDITS.md` for the source and image rights.
