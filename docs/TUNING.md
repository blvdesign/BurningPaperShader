# Tuning

`BurningPaperConfiguration.default` is the reference appearance. Change a few
related values at a time, then compare tap, drag, and multi-point burns at the
same view size. Values outside the documented ranges are clamped before use;
`NaN` falls back to the corresponding default.

## Propagation

| Parameter | Range | Effect |
| --- | ---: | --- |
| `burnSpeed` | `0.01...3.0` | Overall simulation speed. Start here for timing changes. |
| `spreadRate` | `0...3.0` | Rate at which heat advances into intact paper. |
| `coolingRate` | `0...2.0` | How quickly the active edge loses heat. |
| `ignitionRadius` | `0.005...0.2` | Initial normalized size of each ignition. |
| `ignitionVariance` | `0...1` | Shape and strength variation between ignition samples. |

Higher speed and spread can make the front advance quickly enough to hide
fine edge behavior. Increase them gradually. A large ignition radius can make
taps dominate the result before propagation becomes visible.

## Edge structure

| Parameter | Range | Effect |
| --- | ---: | --- |
| `edgeWidth` | `0.001...0.25` | Width of the active burning transition. |
| `stainWidth` | `0.001...0.25` | Width of the brown heat stain ahead of the edge. |
| `charWidth` | `0.001...0.15` | Width of the dark charred rim. |
| `glowAmount` | `0...1` | Intensity of hot edge emission. |
| `noiseStrength` | `0...1` | Spatial variation in material resistance and spread. |
| `frontComplexity` | `0...1` | Irregularity and segmentation of the burn front. |

Tune widths as a group. A broad stain with a narrower char rim usually reads
more naturally than making every band equally wide. High noise and front
complexity can create lively edges, but together they may make small burns
look fragmented.

## Material and atmosphere

| Parameter | Range | Effect |
| --- | ---: | --- |
| `flameAmount` | `0...1` | Visible red/orange flame hints at the active front. |
| `paperWrinkleAmount` | `0...1` | Procedural paper wrinkle contrast. |
| `smokeAmount` | `0...1` | Grey smoke and ash shading near the edge. |
| `emberAmount` | `0...1` | Sparse glowing flecks along hot areas. |
| `paperColor` components | `0...1` | Base RGB color and overall alpha of the paper layer. |

Flame, smoke, and embers are shader details rather than particle systems.
Check them against both light and dark backgrounds. Strong values can obscure
the edge structure or create clipping on bright displays.

## Practical workflow

1. Establish timing with `burnSpeed`, `spreadRate`, and `coolingRate`.
2. Set the initial touch scale with `ignitionRadius` and
   `ignitionVariance`.
3. Shape the edge with its three widths, then add noise and complexity.
4. Adjust glow, flame, smoke, and embers while viewing the effect in motion.
5. Finish with paper color and wrinkles against the intended background.

For intentional visual changes, capture the default before and after at the
same size and ignition points. Test on an iOS simulator and preferably on
physical hardware. Watch for frame drops during rapid drags, abrupt circular
fronts, noisy alpha edges, lost paper detail, and reset artifacts.

The simulation resolution is capped at 1024 pixels on its longest dimension.
Changes that rely on very fine procedural detail may look different across
view sizes, display scales, and devices.
