# Natural vision assets

This Unreal Engine 5.5 project contains the original assets for the Natural night vision prototype. Open `Dawnwalker.uproject` with Unreal Editor 5.5.4. The assets use engine classes only; they require no custom runtime plugin or native DLL.

`M_NaturalVision` is a post-process material at **Scene Color After Tonemapping**. It samples `PostProcessInput0` once and blends an enhanced scene colour into the original with a smooth oval in viewport coordinates. Its Custom expression is also provided as `SourceAssets/NaturalVision.hlsl`; update the expression when editing that source file.

The brightness curve scales all three colour channels equally, using the brightest channel to approach the SDR white limit smoothly. Black stays black, 100% brightness is neutral, and values above SDR white pass through. The oval is relative to the viewport, with a small guard margin that remains outside the effect even at maximum size. This is an SDR design; HDR output needs separate validation.

`BP_NaturalVisionComponent` derives from `PostProcessComponent`. Its defaults disable the component and ticking, enable unbound coverage, and leave all ordinary post-process overrides disabled. It holds its own dynamic material instance and adds only that instance as a blendable.

The component exposes these functions:

| Function | Purpose |
| --- | --- |
| `InitializeNatural()` | Create and retain the material instance, register its blendable, and return whether the instance is valid. Call once on each new component. |
| `ConfigureNatural(BrightnessPercent, FocusSizePercent, SoftnessPercent)` | Set the three scalar parameters. Brightness accepts 25–300, size 40–100 and softness 20–100. Suggested values are 200, 90 and 70. |

Create the component on the current player actor with deferred registration, initialize and configure it, finish registration, then set `bEnabled`. Disable and destroy the owned component when its player or camera is no longer current. `src/Natural.lua` supplies bounded creation, configuration and cleanup without calling blendable interfaces from Lua. The normal entry point does not enable this prototype yet.

The Lua module loads the generated class directly through `KismetSystemLibrary.MakeSoftClassPath`, `Conv_SoftClassPathToSoftClassRef` and `LoadClassAsset_Blocking`. UE4SS's `LoadAsset` searches the game's asset registry, which does not contain these original mod assets. The direct load uses the mounted package without replacing or modifying the game's registry.

For Windows cooking, use the project's packaging settings and retain inline material shader code. Include only the two assets under `Content/NightVisionConfigurable` in the mod's container. Keep their `/Game/NightVisionConfigurable` package names and the `Dawnwalker` project mount. The project settings, editor source assets and engine content are authoring inputs, not game deployment files.

The development archive retains Radius and Fullscreen and includes this prototype through an optional F8 preview. The Natural menu mode and live size/softness settings depend on confirming the cooked assets in Dawnwalker.

`preview/main.lua` is the optional F8 test entry point. The current development package uses it in place of `src/main.lua`, together with the other Lua modules and the cooked original assets. Its README, layout note and Vortex override instructions are in `preview/`. This uses game-relative paths under `Dawnwalker/` for both the Lua payload and the container; its `Data` directory contains the layout note only. Keep the Natural menu mode disabled until the prototype is confirmed in game.
