# BurningPaper Open-Source Package Design

## Goal

Publish the burning-paper effect as a reusable open-source Swift Package. The
shader and simulation are the primary product; the iOS application remains as
an executable example and visual tuning tool.

The first release targets iOS 18 and later and uses the MIT License with:

`Copyright (c) 2026 Nikita Belov`

## Repository Shape

Use one repository named `BurningPaperShader`. Its package product and Swift
module are named `BurningPaper`.

```text
BurningPaperShader/
|-- Package.swift
|-- Sources/BurningPaper/
|   |-- BurningPaperView.swift
|   |-- BurningPaperController.swift
|   |-- BurningPaperConfiguration.swift
|   |-- Rendering/
|   |-- Simulation/
|   `-- Shaders/
|-- Tests/BurningPaperTests/
|-- Example/
|-- docs/media/
|-- README.md
|-- LICENSE
|-- ATTRIBUTIONS.md
`-- CONTRIBUTING.md
```

The package must build independently of the Example application. The Example
application owns its controls, background image, and demonstration-specific
UI. The package has no dependency on those assets.

## Public API

The main SwiftUI API contains three public types:

- `BurningPaperView` renders a transparent procedural paper layer and handles
  tap and continuous-drag ignition by default.
- `BurningPaperController` provides programmatic `ignite(at:)`,
  `ignite(path:)`, and `reset()` commands.
- `BurningPaperConfiguration` contains supported appearance and simulation
  parameters with documented ranges and a stable default preset.

The background remains ordinary SwiftUI content beneath `BurningPaperView`.
The package does not receive or render the revealed content.

```swift
import BurningPaper

ZStack {
    MyBackgroundView()

    BurningPaperView(
        controller: controller,
        configuration: .default
    )
}
```

The package also exposes a lower-level Metal renderer for custom integrations.
GPU uniform layouts, queue management, simulation textures, and other internal
implementation types remain private.

Programmatic ignition points use normalized coordinates in the `0...1` range,
so commands are independent of view size. Configuration can be updated while
the simulation is running.

## First-Release Scope

Version 0.1.0 includes:

- iOS 18 and later support;
- SwiftUI integration and a lower-level Metal renderer;
- built-in tap and drag gestures;
- programmatic point, path, and reset commands;
- configurable procedural paper color, wrinkles, grain, and fibers;
- configurable propagation, edge, heat, smoke, ember, and flame behavior;
- one independent GPU simulation per component;
- an iOS Example application.

Version 0.1.0 does not include:

- custom paper image textures;
- serialized or restorable simulation state;
- burned-area progress or completion callbacks;
- a separate UIKit convenience component;
- multiple package presets beyond the documented default unless they emerge
  naturally during API extraction.

## Metal Resources and Rendering

Metal shaders live inside the Swift Package target and are loaded from the
package resource bundle rather than the host application's default library.
This is required for reliable Swift Package Manager integration.

The rendered paper layer remains transparent where material has burned away.
Simulation state stays on the GPU. Its longest dimension is capped at roughly
1024 pixels to keep memory use and frame time stable. Ignition work is bounded
per frame and the pending queue is capped to prevent gesture bursts from
creating persistent latency.

If the SwiftUI component cannot initialize Metal, it displays a static paper
layer instead of unexpectedly revealing the background. The lower-level
renderer reports a descriptive initialization error. Debug builds retain
enough detail to diagnose shader-library and pipeline failures.

## Testing and Verification

Automated coverage includes:

- configuration range sanitization;
- deterministic ignition-path planning and coordinate clamping;
- controller command behavior;
- independent Swift Package compilation;
- Metal resource and pipeline creation;
- Example application compilation for an iOS simulator.

GitHub Actions runs package tests and builds the Example application using an
available iOS simulator. Release verification also includes a short manual
visual pass on a physical iPhone for touch response, animation continuity, and
performance.

## Documentation and Licensing

The README contains:

- a concise description and visual demo;
- installation through Swift Package Manager;
- a minimal SwiftUI integration example;
- gesture and controller usage;
- configuration guidance;
- platform and Xcode requirements;
- an architecture and performance overview;
- links to credits and visual inspiration.

The repository includes the MIT License, `CONTRIBUTING.md`, architecture and
tuning documentation, and `ATTRIBUTIONS.md`. The current abstract background
image remains only in the Example application and is identified as generated
with OpenAI. External references are linked as inspiration; their images,
videos, and code are not copied into the repository unless their licenses are
explicitly compatible.

Before publication, remove the personal Apple development team identifier,
replace `com.codex.*` bundle identifiers in the Example project, remove local
Xcode data and build artifacts, and retire internal working documents that are
not useful to package consumers.

The initial public release is tagged `v0.1.0`. A Code of Conduct, issue
templates, custom paper textures, and a more elaborate release system are
deferred until there is evidence they are needed.
