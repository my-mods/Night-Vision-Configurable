// Original Radius vision: enhance visible surfaces inside a player-centred sphere.
// Unreal world positions and the private owner origin are in centimetres.
float outer = clamp(RadiusMeters, 5.0, 50.0) * 100.0;
float d = length(SurfacePosition.xyz - Origin.xyz);
float mask = 1.0 - smoothstep(outer * 0.35, outer, d);
float gain = clamp(BrightnessPercent * 0.01, 0.25, 5.0);
float peak = max(0.0, max(Scene.r, max(Scene.g, Scene.b)));
float scale = gain / (1.0 + (gain - 1.0) * saturate(peak));
scale = peak > 1.0 ? 1.0 : scale;
float3 bright = Scene.rgb * scale;
float red = saturate(RedTintPercent * 0.01);
bright *= float3(1.0, 1.0-red, 1.0-red);
return lerp(Scene.rgb, bright, mask);
