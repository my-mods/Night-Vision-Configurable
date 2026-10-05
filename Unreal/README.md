# Night vision assets

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

For Windows cooking, use the project's packaging settings and retain inline material shader code. Include only the four assets under `Content/NightVisionConfigurable` in the mod's container. Keep their `/Game/NightVisionConfigurable` package names and the `Dawnwalker` project mount. The project settings, editor source assets and engine content are authoring inputs, not game deployment files.

The archive includes Radius, Fullscreen and Natural. Mode 2 (Natural) is the default for new configurations; existing saved mode choices are preserved. Natural adds `naturalFocusSize` (40–100, default 90) and `naturalSoftness` (20–100, default 70), both in 5-point steps, and reuses `brightnessPercent` for the central enhancement. Successful component recreation resets the failed-attempt budget; repeated menu visits do not exhaust it.

`preview/main.lua` retains the earlier optional F8 authoring test; it is not the normal package entry point. Production uses `src/main.lua` and the metadata/layout files under `package/`. Both Lua and cooked containers use game-relative paths under `Dawnwalker/`; `Data` contains only a layout note.


## Radius vision

`M_RadiusVision` and `BP_RadiusVisionComponent` provide mode 0 with original post-process assets. Radius shares Natural's SDR brightness curve but uses reconstructed visible surface world position and a private player-origin vector. The distance mask is full strength through 35% of the selected radius and fades smoothly to zero at its outer limit. Radius is measured from the player actor, independently of camera offset. It adds no point light, shadows, indirect lighting or specular highlights. Fully black pixels remain black. Depth-based surface selection follows the opaque depth buffer; transparent surfaces need gameplay evaluation.

`InitializeRadius()` creates the owned dynamic material. `ConfigureRadius(BrightnessPercent, RadiusMeters, RedTintPercent)` accepts the existing brightness 25–300%, radius 5–50 metres and red tint 0–100%. `UpdateRadiusOrigin()` obtains the component owner's position and writes `RadiusOrigin` only after movement beyond 0.01 centimetres. The same function runs from the Blueprint's `ReceiveTick` event in Post Update Work while enabled. Tick starts disabled; the Lua manager performs the initial update, finishes registration and enables ticking only for active Radius. It stops ticking and destroys the component on menus, loads, mode changes, deactivation and owner/camera replacement. Settings never use this tick.

Black & White and Keep blood red retain Radius's existing global camera treatment. Radius brightness and red tint are then applied inside the distance mask; the vampire border stays independent. Natural and Fullscreen retain their own behavior. HDR and temporal upscaling require validation in the target game.

Cook all four original assets together and retain their inline shaders. Runtime assets use only engine classes; the authoring plugin is not needed in game. `SourceAssets/RadiusVision.hlsl` is the material's Custom expression source. The component's Blueprint graph is editable in Unreal Editor 5.5.4.

`ConfigureRadiusLogging(Enabled)` follows the existing Logging setting. With it Off, no diagnostic counters advance. With it On, `RadiusChecks` and `RadiusWrites` accumulate for the current component and appear in the existing aggregate log window. No per-frame logging or additional Lua timer is used.
