// Original Natural vision: one point-sampled scene read, no neighbouring pixels.
// Parameters are percentages matching the mod's settings, with 100% neutral gain.
float radius = clamp(FocusSizePercent * 0.01, 0.4, 1.0) * 0.98;
float softness = clamp(SoftnessPercent * 0.01, 0.2, 1.0);
float distance = length((ViewportUV * 2.0 - 1.0) / radius);
float mask = 1.0 - smoothstep(1.0 - softness, 1.0, distance);
float gain = clamp(BrightnessPercent * 0.01, 0.25, 5.0);
float peak = max(0.0, max(Scene.r, max(Scene.g, Scene.b)));
// Preserve channel ratios. The SDR white point and black remain fixed.
float scale = gain / (1.0 + (gain - 1.0) * saturate(peak));
// Values above the SDR white point pass through without being clipped.
scale = peak > 1.0 ? 1.0 : scale;
float3 bright = Scene.rgb * scale;
float mono = saturate(MonochromePercent * 0.01);
// Classify reds from the input, independent of the selected brightness gain.
float3 colour = max(Scene.rgb, 0.0);
float high = max(colour.r, max(colour.g, colour.b));
float low = min(colour.r, min(colour.g, colour.b));
float chroma = high - low;
float hue = abs(colour.g - colour.b) / max(chroma, 0.000001) * 60.0;
float saturation = chroma / max(high, 0.000001);
float keep = (colour.r >= colour.g && colour.r >= colour.b) ? 1.0 : 0.0;
keep *= (1.0 - smoothstep(12.0, 28.0, hue)) * smoothstep(0.06, 0.2, saturation)
    * smoothstep(1.0 / 15.0, 0.1, chroma) * saturate(KeepBloodRed);
float grey = dot(bright, float3(0.2126, 0.7152, 0.0722));
float brightPeak = max(0.0, max(bright.r, max(bright.g, bright.b)));
float redGain = min(clamp(RedBrightnessPercent * 0.01, 1.0, 5.0), 1.0 / max(brightPeak, 0.000001));
redGain = brightPeak > 1.0 ? 1.0 : redGain;
float3 monochrome = lerp(grey.xxx, bright * redGain, keep);
float3 enhanced = lerp(bright, monochrome, mono);
// One shared fade: all mod colour treatment ends at the same oval boundary.
return lerp(Scene.rgb, enhanced, mask);
