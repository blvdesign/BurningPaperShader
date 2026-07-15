# Contributing

Thanks for helping improve BurningPaper. Focused bug fixes, performance work,
documentation improvements, and carefully scoped visual refinements are
welcome.

## Requirements

- macOS with Xcode 16 or later
- An iOS 18 or later simulator
- A Metal-capable iPhone or iPad for final rendering checks when available

A newer Xcode or iOS SDK may be needed to match your local simulator or device.
That does not change the package's iOS 18 deployment target.

## Set up

Clone the repository and open its root directory in Xcode. The package has no
external runtime dependencies.

List the simulators available on your machine:

```sh
xcrun simctl list devices available
```

Run the package tests, substituting an installed simulator name:

```sh
xcodebuild test \
  -scheme BurningPaper \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Build the Example application:

```sh
xcodebuild build \
  -project Example/BurningPaperExample.xcodeproj \
  -scheme BurningPaperExample \
  -destination 'generic/platform=iOS Simulator'
```

## Source layout

- `Sources/BurningPaper/Public`: SwiftUI, controller, color, and configuration API
- `Sources/BurningPaper/Rendering`: Metal renderer and SwiftUI bridge
- `Sources/BurningPaper/Simulation`: deterministic ignition planning
- `Sources/BurningPaper/Shaders`: compute and rendering shaders
- `Sources/BurningPaperShaderTypes`: Swift/Metal shared uniform definitions
- `Tests/BurningPaperTests`: public API, simulation, rendering, and ABI tests
- `Example`: package-powered demonstration and tuning application

See [Architecture](docs/ARCHITECTURE.md) for the rendering flow and
[Tuning](docs/TUNING.md) for parameter behavior.

## Making changes

Keep public API additions small and document their behavior, coordinate space,
and valid ranges. Preserve the shared uniform field order unless the Swift and
Metal definitions and their ABI tests are updated together.

Rendering changes require more than a successful compile. Check the intact
paper, tap and drag ignition, multiple ignition points, edge evolution,
transparency, reset behavior, and fast interaction on an iOS simulator.
Preferably repeat the pass on physical hardware, where timing and GPU behavior
can differ. Include before-and-after captures for intentional visual changes.

Add or update focused tests for behavioral changes. Avoid committing build
products, result bundles, local captures, signing identities, or generated user
data.

## Pull requests

Describe the user-visible result, test commands run, and any remaining visual
or performance trade-offs. Keep unrelated refactors out of the same change.
