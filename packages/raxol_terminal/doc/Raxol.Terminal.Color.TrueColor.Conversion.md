# `Raxol.Terminal.Color.TrueColor.Conversion`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/color/true_color/conversion.ex#L1)

Color space math for TrueColor: RGB/HSL/HSV/XYZ/Lab conversions
and luminance calculations.

# `hsl_to_rgb`

Converts HSL (h in 0..360, s/l in 0..1) to normalized RGB (0..1 each).

# `hsv_to_rgb`

Converts HSV (h in 0..360, s/v in 0..1) to normalized RGB (0..1 each).

# `relative_luminance`

Calculates relative luminance for an 8-bit RGB color (WCAG formula).

# `rgb_to_hsl`

Converts normalized RGB (0..1 each) to HSL tuple {h, s, l}
where h is 0..360, s and l are 0..100.

# `rgb_to_hsv`

Converts normalized RGB (0..1 each) to HSV tuple {h, s, v}
where h is 0..360, s and v are 0..100.

# `to_xyz`

Converts an 8-bit RGB struct to XYZ color space.

# `xyz_to_lab`

Converts XYZ to CIELAB (L*, a*, b*) using D65 illuminant.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
