// Original Natural vision: one point-sampled scene read, no neighbouring pixels.
// Parameters are percentages matching the mod's settings, with 100% neutral gain.
float radius = clamp(FocusSizePercent * 0.01, 0.4, 1.0) * 0.98;
float softness = clamp(SoftnessPercent * 0.01, 0.2, 1.0);
float distance = length((ViewportUV * 2.0 - 1.0) / radius);
float mask = 1.0 - smoothstep(1.0 - softness, 1.0, distance);
float gain = clamp(BrightnessPercent * 0.01, 0.25, 3.0);
float peak = max(0.0, max(Scene.r, max(Scene.g, Scene.b)));
// Preserve channel ratios. The SDR white point and black remain fixed.
float scale = gain / (1.0 + (gain - 1.0) * saturate(peak));
// Values above the SDR white point pass through without being clipped.
scale = peak > 1.0 ? 1.0 : scale;
return lerp(Scene.rgb, Scene.rgb * scale, mask);
