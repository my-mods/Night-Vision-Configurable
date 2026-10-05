# Natural vision assets

This Unreal Engine 5.5 project contains the original assets for Natural night vision. Open `Dawnwalker.uproject` with Unreal Editor 5.5.4. The assets use engine classes only; they require no custom runtime plugin or native DLL.

`M_NaturalVision` is a post-process material at **Scene Color After Tonemapping**. It samples `PostProcessInput0` once and blends brightness and colour treatment into the original with one smooth oval in viewport coordinates. Monochrome, red preservation and red brightness share that mask, leaving the input unchanged outside it. Its Custom expression is also provided as `SourceAssets/NaturalVision.hlsl`; update the expression when editing that source file.

The brightness curve scales all three colour channels equally, using the brightest channel to approach the SDR white limit smoothly. Black stays black, 100% brightness is neutral, and values above SDR white pass through. The oval is relative to the viewport, with a small guard margin that remains outside the effect even at maximum size. This is an SDR design; HDR output needs separate validation.

`BP_NaturalVisionComponent` derives from `PostProcessComponent`. Its defaults disable the component and ticking, enable unbound coverage, and leave all ordinary post-process overrides disabled. It holds its own dynamic material instance and adds only that instance as a blendable.

The component exposes these functions:

| Function | Purpose |
| --- | --- |
| `InitializeNatural()` | Create and retain the material instance, register its blendable, and return whether the instance is valid. Call once on each new component. |
| `ConfigureNatural(BrightnessPercent, FocusSizePercent, SoftnessPercent)` | Set brightness (25–300), size (40–100) and softness (20–100). Suggested values are 200, 90 and 70. |
| `ConfigureNaturalColour(MonochromePercent, KeepBloodRed, RedBrightnessPercent)` | Set monochrome (0–100), red preservation (0 or 1) and red brightness (100–500), all plain numeric parameters. Defaults are 0, 0 and 100. |

Natural uses no camera saturation or colour-lookup override. Mode changes restore the mod's previous camera overrides through the existing ownership journal. Colour treatment uses the rendered scene after tonemapping, so it need not match the other modes' pre-tonemapping grading exactly. Red selection follows hue, saturation and chroma, not object identity; red gain preserves channel ratios and stays within SDR highlight headroom. The monochrome amount blends that treatment with the enhanced colour before the shared oval blend. Zero monochrome preserves the original Natural brightness result. No extra scene read or rendering pass is added. The Lua module validates both configuration functions before creating a component; older helper assets fail only Natural, with a bounded diagnostic.

Create the component on the current player actor with deferred registration, initialize and configure it, finish registration, then set `bEnabled`. Disable and destroy the owned component when its player or camera is no longer current. `src/Natural.lua` supplies bounded creation, configuration and cleanup without calling blendable interfaces from Lua. `src/main.lua` selects it for mode 2, retains activation intent through supported loading/camera transitions, and releases it on menus, deactivation and human form.

The Lua module loads the generated class directly through `KismetSystemLibrary.MakeSoftClassPath`, `Conv_SoftClassPathToSoftClassRef` and `LoadClassAsset_Blocking`. UE4SS's `LoadAsset` searches the game's asset registry, which does not contain these original mod assets. The direct load uses the mounted package without replacing or modifying the game's registry.

For Windows cooking, use the project's packaging settings and retain inline material shader code. Include only the two assets under `Content/NightVisionConfigurable` in the mod's container. Keep their `/Game/NightVisionConfigurable` package names and the `Dawnwalker` project mount. The project settings, editor source assets and engine content are authoring inputs, not game deployment files.

The archive includes Radius, Fullscreen and Natural. Mode 2 (Natural) is the default for new configurations; existing saved mode choices are preserved. Natural adds `naturalFocusSize` (40–100, default 90) and `naturalSoftness` (20–100, default 70), both in 5-point steps, and reuses `brightnessPercent` for the central enhancement. Successful component recreation resets the failed-attempt budget; repeated menu visits do not exhaust it.

`preview/main.lua` retains the earlier optional F8 authoring test; it is not the normal package entry point. Production uses `src/main.lua` and the metadata/layout files under `package/`. Both Lua and cooked containers use game-relative paths under `Dawnwalker/`; `Data` contains only a layout note.
