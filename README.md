# Night Vision - Configurable

Toggle vampire night vision with **N** or by holding **L3 / the left stick for 0.6 seconds**. Release the stick between toggles. Once enabled, vision stays on until you toggle it off or return to human form. Camera changes, save loading and player replacement preserve your choice and automatically resume the effect when a vampire player and camera are ready. A new game session starts with vision off.

Choose **Night Vision Mode: Radius / Fullscreen / Natural**. Radius adds soft light centered on your character, spreading evenly around you with a gradual fade and reduced shiny highlights. Its **Light radius** slider appears only in Radius mode: **5–50 metres**, in **1-metre steps**, default **6 metres**. Fullscreen brightens the whole view. **Natural is the default for new configurations**; existing saved mode choices are preserved.

**Natural** brightens a broad oval around the camera aim, including distant scenery, then fades into the normal night image at the edges. **Natural size** controls the outer oval’s width and height relative to the viewport: **40–100%**, default **90%**. **Fade softness** controls how much of its radius fades gradually: **20–100%**, default **70%**. Both sliders use **5% steps** and appear only in Natural mode. Natural uses N/L3 like the other modes, with no activation flash or time limit. Use SDR output; HDR needs separate validation.

**Brightness** runs from **25% to 300%**, in **5% steps**, default **200%**. In Fullscreen and Natural modes, 100% keeps normal game brightness. Natural adjusts only the central enhancement, retaining colour ratios and highlight headroom; fully black pixels stay black. With Vignette off or at zero, its outer margins retain normal vision even with Black & White enabled. Neither mode changes exposure or adds bloom. In Radius mode, 100% is the light’s standard strength. Fullscreen activation includes a brief brightness pulse; all modes use the game’s loaded focus sound when available.

**Vignette** reuses the game's vampire blood-hunger texture: irregular red veins fade softly inward from the edges. It uses its own overlay and does not trigger hunger or low-health effects. It defaults to On at **20% opacity**. Its **0–100% slider**, in **5% steps**, appears only when On. Off or 0% removes the border. It is independent of the game's damage effects.

**Black & White** uses **0%** for natural colours and **100%** for black and white. In Natural mode it affects only the bright oval, fading back to normal colour with the same size and softness as the light. Radius and Fullscreen apply it to the whole view. **Red tint** colours only the added light in Radius mode, so unlit areas keep their colours. In Fullscreen mode, it colours the whole view. It is hidden and unused in Natural mode, retaining its saved value. Both controls use **0–100%**, in **5% steps**, default **0%**. The vignette stays red independently.

**Keep blood red** is an optional toggle under Black & White, default **Off**. On preserves red shades while the slider removes other colours, so blood and the vampire vignette can stay red together. It also preserves similarly red clothing and objects. Dark or discoloured blood may lose some colour, and lighting still affects the result. Use it with **HDR output off**. In Natural mode, red preservation follows the oval too. In Radius and Fullscreen, HDR output, an unavailable filter or another camera colour filter taking priority falls back to ordinary Black & White; the vignette stays red.

**Red brightness** appears when Keep blood red is On. It runs from **100% to 500% in 10% steps**, default **100%** for the original brightness. Higher values brighten preserved reds in the world, including other red objects. In Natural mode, this enhancement fades out with the oval and leaves outer colours unchanged. The Black & White slider controls how strongly this colour filter is applied; already bright reds can reach the display's brightness limit. The vampire border has separate controls. Turning Keep blood red Off hides the slider and retains its saved value.

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

The Lua sources are in `src`. Copy all ten modules into `Dawnwalker/Binaries/Win64/ue4ss/Mods/NightVisionConfigurable/Scripts`. Copy all PNG files from `assets` into that mod’s `Textures` folder, and put `package/enabled.txt` and `package/mod_settings.ini` at the mod root. The pinned common modules and unchanged menu helper are already bundled.

The [Natural assets](Unreal/README.md) supply the original Unreal 5.5.4 material/Blueprint source and cooking details. Put the cooked container in `Dawnwalker/Content/Paks/~mods`. No native DLL is required. The earlier F8 preview entry point is an optional authoring test and is not included in the normal package.

Put `package/mod.manifest`, a UTF-8 `README.txt` made from this README, `package/vortex_override_instructions.json` and the license files at archive root. Copy `package/NightVisionConfigurable-Layout.txt` into `Data`; it is a layout note, not runtime payload. Keep the `Nexus` release materials, changelog, release notes and provenance files at archive root, outside the `Dawnwalker` runtime folder.

## Credits

Inspired by [Night Vision by opogode](https://www.nexusmods.com/thebloodofdawnwalker/mods/294), made with permission. This independent implementation does not redistribute that mod's script or assets. Rebel Wolves created The Blood of Dawnwalker. UE4SS provides the Lua runtime. Dawnwalker Mod Menu by mmarcussa provides the settings UI and its unchanged integration helper, copied as directed by its integration guide. The bundled [ue4ss-common](https://github.com/my-mods/ue4ss-common) settings modules are MIT licensed; see `LICENSES/ue4ss-common.txt`.

The banner and thumbnail use an official Rebel Wolves gameplay screenshot with permission. See `Nexus/MEDIA-CREDITS.md` for the source and image rights.
