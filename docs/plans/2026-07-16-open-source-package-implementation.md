# BurningPaper Open-Source Package Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert the current iOS prototype into an iOS 18+ MIT-licensed Swift Package named `BurningPaper`, with a reusable SwiftUI component, a programmatic controller, a lower-level Metal renderer, and a separate Example application.

**Architecture:** Keep the GPU simulation and transparent paper rendering inside the package, compile `Shaders.metal` into the package resource bundle, and load it with `device.makeDefaultLibrary(bundle: Bundle.module)`. Expose a small public API (`BurningPaperView`, `BurningPaperController`, `BurningPaperConfiguration`, and `BurningPaperRenderer`) while keeping ignition planning, uniform layouts, simulation textures, and queueing internal. Move the existing app into `Example` and make it consume the local package instead of compiling a second copy of the renderer.

**Tech Stack:** Swift 5.10 package manifest, SwiftUI, UIKit bridge, MetalKit, Metal Shading Language, XCTest, Xcode 26, GitHub Actions, iOS 18+

---

### Task 1: Capture and verify the current prototype baseline

**Files:**
- Add: `.gitignore`
- Add: `BurningPaperShader.xcodeproj/project.pbxproj`
- Add: `BurningPaperShader/**`
- Add: `BurningPaperShaderTests/**`
- Add: `README.md`
- Delete later: `docs/superpowers/plans/2026-06-30-burning-paper-ios-mvp.md`

**Step 1: Inspect the untracked baseline for private and generated data**

Run:

```bash
git status --short
rg -n "/Users/|macbook|DEVELOPMENT_TEAM|com\\.codex|API[_-]?KEY|TOKEN|PASSWORD" . \
  -g '!*.xcuserstate' -g '!DerivedData' -g '!build'
```

Expected: only the known Apple team identifier and `com.codex.*` bundle identifiers are reported; no credentials or absolute local paths are present.

**Step 2: Verify the current app before moving files**

Run:

```bash
xcodebuild test \
  -project BurningPaperShader.xcodeproj \
  -scheme BurningPaperShader \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: `** TEST SUCCEEDED **`.

**Step 3: Commit the prototype baseline without Xcode user data**

Run:

```bash
git add .gitignore BurningPaperShader.xcodeproj BurningPaperShader BurningPaperShaderTests README.md docs/superpowers
git status --short
git commit -m "chore: capture burning paper prototype"
```

Expected: source, tests, project, and current documentation are committed; no `xcuserdata`, DerivedData, result bundles, recordings, or downloaded references are staged.

### Task 2: Add the Swift Package skeleton and shared shader types

**Files:**
- Create: `Package.swift`
- Create: `Sources/BurningPaperShaderTypes/include/BurningPaperShaderTypes.h`
- Create: `Sources/BurningPaperShaderTypes/BurningPaperShaderTypes.m`
- Create: `Sources/BurningPaper/BurningPaper.swift`
- Create: `Tests/BurningPaperTests/PackageSmokeTests.swift`

**Step 1: Write a package smoke test before the product exists**

Create `Tests/BurningPaperTests/PackageSmokeTests.swift`:

```swift
import XCTest
@testable import BurningPaper

final class PackageSmokeTests: XCTestCase {
    func testModuleExportsVersion() {
        XCTAssertEqual(BurningPaper.version, "0.1.0")
    }
}
```

**Step 2: Run the test and verify that the package is missing**

Run:

```bash
xcodebuild test -scheme BurningPaper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: FAIL because `Package.swift` and the `BurningPaper` scheme do not exist.

**Step 3: Create the package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BurningPaperShader",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "BurningPaper", targets: ["BurningPaper"])
    ],
    targets: [
        .target(
            name: "BurningPaperShaderTypes",
            publicHeadersPath: "include"
        ),
        .target(
            name: "BurningPaper",
            dependencies: ["BurningPaperShaderTypes"]
        ),
        .testTarget(
            name: "BurningPaperTests",
            dependencies: ["BurningPaper"]
        )
    ]
)
```

Create `Sources/BurningPaper/BurningPaper.swift`:

```swift
public enum BurningPaper {
    public static let version = "0.1.0"
}
```

Create `Sources/BurningPaperShaderTypes/BurningPaperShaderTypes.m` as an empty compilation unit that imports its public header.

**Step 4: Define one shared CPU/GPU uniform layout**

Move the fields currently duplicated by `ShaderTypes.swift` and `Shaders.metal` into `BurningPaperShaderTypes.h`. Use `vector_float2`, `vector_float4`, `float`, and `uint32_t`, preserve field order, and add `paperColor` after `viewSize`:

```c
#ifndef BurningPaperShaderTypes_h
#define BurningPaperShaderTypes_h

#include <simd/simd.h>

typedef struct {
    vector_float2 textureSize;
    vector_float2 viewSize;
    vector_float4 paperColor;
    float time;
    float deltaTime;
    vector_float2 ignitionPoint;
    /* Preserve all existing scalar fields in current order. */
} BurningPaperUniforms;

#endif
```

Do not expose this target as a package product. It is an implementation dependency used to prevent Swift and Metal layouts from drifting.

**Step 5: Run the package smoke test**

Run:

```bash
xcodebuild test -scheme BurningPaper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: `PackageSmokeTests` passes.

**Step 6: Commit**

```bash
git add Package.swift Sources Tests/BurningPaperTests/PackageSmokeTests.swift
git commit -m "build: add BurningPaper Swift package"
```

### Task 3: Extract and test the public configuration API

**Files:**
- Create: `Sources/BurningPaper/Public/BurningPaperColor.swift`
- Create: `Sources/BurningPaper/Public/BurningPaperConfiguration.swift`
- Create: `Tests/BurningPaperTests/BurningPaperConfigurationTests.swift`
- Reference: `BurningPaperShader/Metal/BurnParameters.swift`

**Step 1: Write failing tests for defaults and clamping**

Create tests that assert:

```swift
func testDefaultConfigurationUsesNaturalPaperColor() {
    XCTAssertEqual(BurningPaperConfiguration.default.paperColor, .naturalWhite)
}

func testConfigurationClampsUnsafeValues() {
    var value = BurningPaperConfiguration.default
    value.burnSpeed = -10
    value.smokeAmount = 5
    let safe = value.sanitized
    XCTAssertEqual(safe.burnSpeed, 0.01)
    XCTAssertEqual(safe.smokeAmount, 1.0)
}
```

Also port every range assertion from `BurnParametersTests.testSanitizedClampsUnsafeValues` so no parameter loses validation during extraction.

**Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -scheme BurningPaper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:BurningPaperTests/BurningPaperConfigurationTests
```

Expected: FAIL because the public configuration types do not exist.

**Step 3: Implement the public value types**

`BurningPaperColor` is a small `Equatable`, `Sendable` RGBA value with clamped components and a `.naturalWhite` preset. `BurningPaperConfiguration` ports all current `BurnParameters` values, uses public documented properties, supplies `.default`, and keeps `sanitized` internal.

Use the current defaults without visual retuning. Add the new default paper color close to the shader's existing base paper color so extraction does not change screenshots.

**Step 4: Run all package tests**

Run:

```bash
xcodebuild test -scheme BurningPaper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: all package tests pass.

**Step 5: Commit**

```bash
git add Sources/BurningPaper/Public Tests/BurningPaperTests/BurningPaperConfigurationTests.swift
git commit -m "feat: add public burn configuration"
```

### Task 4: Extract ignition planning and add the public controller

**Files:**
- Create: `Sources/BurningPaper/Public/BurningPaperController.swift`
- Create: `Sources/BurningPaper/Simulation/BurnIgnition.swift`
- Create: `Sources/BurningPaper/Simulation/BurnIgnitionPlanner.swift`
- Create: `Tests/BurningPaperTests/BurningPaperControllerTests.swift`
- Create: `Tests/BurningPaperTests/BurnIgnitionPlannerTests.swift`
- Reference: `BurningPaperShader/Metal/MetalView.swift`

**Step 1: Port the deterministic planner tests first**

Move the current tests for continuous ignition variation into the package test target. Add coordinate clamping tests for points below `0` and above `1`.

Expected public behavior test:

```swift
func testControllerPublishesPointPathAndResetCommands() {
    let controller = BurningPaperController()

    controller.ignite(at: CGPoint(x: 0.25, y: 0.75))
    XCTAssertEqual(controller.pendingCommand?.kind, .ignite)

    controller.ignite(path: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
    XCTAssertEqual(controller.pendingCommand?.points.count, 2)

    controller.reset()
    XCTAssertEqual(controller.pendingCommand?.kind, .reset)
}
```

Keep command payloads internal and expose only the methods publicly.

**Step 2: Run tests and verify failure**

Run the two new test classes with `xcodebuild test -only-testing` and expect missing-type failures.

**Step 3: Implement the controller and internal planner**

Implement `BurningPaperController` as a main-thread `ObservableObject`. Every command gets a new monotonically changing revision or UUID so repeated ignition at the same point is not coalesced by SwiftUI. Clamp public points to normalized coordinates before publishing the command.

Port `SeededRandomNumberGenerator`, `BurnIgnition`, and `BurnIgnitionPlanner` without changing their ranges. Add a planner entry point that expands an array of path points into varied internal ignitions.

**Step 4: Run tests**

Run all package tests and expect PASS.

**Step 5: Commit**

```bash
git add Sources/BurningPaper/Public/BurningPaperController.swift \
  Sources/BurningPaper/Simulation Tests/BurningPaperTests
git commit -m "feat: add programmatic burn controller"
```

### Task 5: Move the Metal renderer and shader into the package

**Files:**
- Create: `Sources/BurningPaper/Rendering/BurningPaperRenderer.swift`
- Create: `Sources/BurningPaper/Rendering/BurningPaperRendererError.swift`
- Create: `Sources/BurningPaper/Shaders/Shaders.metal`
- Create: `Tests/BurningPaperTests/BurningPaperRendererTests.swift`
- Reference: `BurningPaperShader/Metal/BurnRenderer.swift`
- Reference: `BurningPaperShader/Metal/Shaders.metal`
- Reference: `BurningPaperShader/Metal/ShaderTypes.swift`

**Step 1: Write a failing renderer initialization test**

```swift
import Metal
import XCTest
@testable import BurningPaper

final class BurningPaperRendererTests: XCTestCase {
    func testRendererLoadsPackageMetalLibrary() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        _ = try BurningPaperRenderer(
            device: device,
            colorPixelFormat: .bgra8Unorm
        )
    }
}
```

**Step 2: Run the test and verify failure**

Expected: FAIL because `BurningPaperRenderer` does not exist.

**Step 3: Port the renderer with a throwing initializer**

Rename `BurnRenderer` to `BurningPaperRenderer`, make the class and supported control methods public, and keep textures, command encoding, and ignition queueing private. Replace:

```swift
device.makeDefaultLibrary()
```

with:

```swift
let library = try device.makeDefaultLibrary(bundle: Bundle.module)
```

Report distinct `BurningPaperRendererError` cases for command queue creation, shader library loading, missing shader functions, compute pipeline creation, and render pipeline creation. Keep `ignite`, `reset`, and configuration updates callable by the SwiftUI bridge.

**Step 4: Port the shader without visual changes**

Move `Shaders.metal` into the package target. Replace its local uniform struct with:

```metal
#include "../../BurningPaperShaderTypes/include/BurningPaperShaderTypes.h"
```

Rename the shader parameter type to `BurningPaperUniforms`. Replace the hard-coded base paper color in the fragment stage with `uniforms.paperColor.rgb`, preserving the existing grain, wrinkles, stain, char, heat, ash, smoke, flame, and ember calculations.

**Step 5: Verify Metal compilation and renderer creation**

Run:

```bash
xcodebuild test -scheme BurningPaper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:BurningPaperTests/BurningPaperRendererTests
```

Expected: the package compiles `Shaders.metal`, `Bundle.module` contains `default.metallib`, and the renderer test passes.

Apple reference: [TN3133: Packaging a Metal renderer](https://developer.apple.com/documentation/technotes/tn3133-packaging-a-renderer).

**Step 6: Commit**

```bash
git add Sources/BurningPaper/Rendering Sources/BurningPaper/Shaders \
  Sources/BurningPaperShaderTypes Tests/BurningPaperTests/BurningPaperRendererTests.swift
git commit -m "feat: package Metal burn renderer"
```

### Task 6: Build the public SwiftUI component and fallback

**Files:**
- Create: `Sources/BurningPaper/Public/BurningPaperView.swift`
- Create: `Sources/BurningPaper/Rendering/BurningPaperMetalView.swift`
- Create: `Tests/BurningPaperTests/BurningPaperViewTests.swift`
- Reference: `BurningPaperShader/Metal/MetalView.swift`
- Reference: `BurningPaperShader/App/ContentView.swift`

**Step 1: Write focused bridge tests**

Extract command-consumption decisions into an internal testable coordinator or reducer. Test that:

- a new controller command is consumed once;
- the same command is not replayed on an unrelated configuration update;
- reset clears pending ignitions;
- interactive drag planning emits multiple varied ignitions;
- `isInteractive == false` disables package-owned gestures.

**Step 2: Run tests and verify failure**

Expected: FAIL because the SwiftUI component and bridge state do not exist.

**Step 3: Implement `BurningPaperMetalView`**

Port the current `UIViewRepresentable` setup. Keep the MTKView transparent, use `.bgra8Unorm`, disable `framebufferOnly`, and prefer 120 FPS. Initialize `BurningPaperRenderer` with `do/catch` and retain the initialization error in the coordinator for debug diagnostics.

**Step 4: Implement `BurningPaperView`**

Expose an initializer equivalent to:

```swift
public init(
    controller: BurningPaperController,
    configuration: BurningPaperConfiguration = .default,
    isInteractive: Bool = true
)
```

Attach the zero-distance drag gesture only when interactive. Keep gesture state and random ignition variation inside the component. The view must remain transparent outside intact or partially burned paper pixels so arbitrary SwiftUI content can show through.

When Metal initialization fails, render an opaque static paper fallback using `configuration.paperColor`. Do not silently reveal the underlying content.

**Step 5: Run package tests and build the package**

Run:

```bash
xcodebuild test -scheme BurningPaper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild build -scheme BurningPaper \
  -destination 'generic/platform=iOS Simulator'
```

Expected: all tests pass and the package builds independently.

**Step 6: Commit**

```bash
git add Sources/BurningPaper Tests/BurningPaperTests
git commit -m "feat: add reusable SwiftUI burn view"
```

### Task 7: Convert the prototype into a package-powered Example app

**Files:**
- Move: `BurningPaperShader.xcodeproj` -> `Example/BurningPaperExample.xcodeproj`
- Move: `BurningPaperShader/App/**` -> `Example/BurningPaperExample/App/**`
- Move: `BurningPaperShader/Assets.xcassets/**` -> `Example/BurningPaperExample/Assets.xcassets/**`
- Modify: `Example/BurningPaperExample/App/ContentView.swift`
- Modify: `Example/BurningPaperExample.xcodeproj/project.pbxproj`
- Delete: `BurningPaperShader/Metal/**`
- Move/replace: `BurningPaperShaderTests/**` -> package tests already created above

**Step 1: Move the Example-owned files**

Use `git mv` for tracked app code, project, and asset catalog. Do not copy the Metal files into Example.

**Step 2: Add the root package as a local package dependency**

Update the Xcode project to reference `..` as an `XCLocalSwiftPackageReference`, add the `BurningPaper` product to the app target, and remove the old Metal source and old test-target file references.

Set:

- deployment target: iOS 18.0;
- bundle identifier: `com.example.BurningPaperExample`;
- signing team: empty;
- automatic signing: enabled for local selection in Xcode;
- display name: `Burning Paper`.

**Step 3: Rewrite the app as a package consumer**

Import `BurningPaper`, replace `BurnParameters`, `BurnTrigger`, `MetalView`, and app-owned gesture state with `BurningPaperConfiguration`, `BurningPaperController`, and `BurningPaperView`. Keep the existing tuning controls and abstract background in Example only.

The app should conceptually reduce to:

```swift
ZStack {
    AbstractBackgroundView()
    BurningPaperView(controller: controller, configuration: configuration)
    overlayControls
}
```

**Step 4: Build and test the Example**

Run:

```bash
xcodebuild build \
  -project Example/BurningPaperExample.xcodeproj \
  -scheme BurningPaperExample \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: `** BUILD SUCCEEDED **` with the package resolved from the repository root and no duplicated shader symbols.

**Step 5: Perform a visual regression pass**

On simulator and iPhone, verify:

- the intact paper matches the current procedural appearance;
- tap and drag ignition both work;
- edge heat, char, smoke, embers, wrinkles, and background reveal remain visually equivalent;
- reset and tuning controls work;
- no status bar or overlay regression appears;
- animation stays responsive during fast drag input.

**Step 6: Commit**

```bash
git add -A Example BurningPaperShader BurningPaperShaderTests BurningPaperShader.xcodeproj
git commit -m "refactor: move demo app to Example"
```

### Task 8: Add open-source documentation and repository hygiene

**Files:**
- Create: `LICENSE`
- Create: `ATTRIBUTIONS.md`
- Create: `CONTRIBUTING.md`
- Create: `CHANGELOG.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/TUNING.md`
- Create: `docs/media/.gitkeep`
- Rewrite: `README.md`
- Modify: `.gitignore`
- Delete: `docs/superpowers/plans/2026-06-30-burning-paper-ios-mvp.md`

**Step 1: Add the MIT license**

Use the standard MIT text with:

```text
Copyright (c) 2026 Nikita Belov
```

**Step 2: Document attribution and asset provenance**

State that `Example/.../AbstractBurnBackdrop.png` was generated with OpenAI and is included only as demonstration media. Link the visual references as inspiration without claiming their code or images are part of the package.

**Step 3: Rewrite the README for package consumers**

Include, in this order:

1. short product description and demo placeholder;
2. features;
3. requirements (`iOS 18+`, Xcode 16+ or the verified minimum);
4. Swift Package Manager URL installation;
5. minimal SwiftUI example;
6. programmatic controller example;
7. configuration example;
8. lower-level renderer note;
9. architecture and performance summary;
10. Example app instructions;
11. attribution, contribution, and license links.

Do not publish a repository URL until the actual GitHub URL is known. Use a clearly marked placeholder that is replaced before `v0.1.0`.

**Step 4: Add contributor and tuning documentation**

Document build/test commands, source layout, visual regression expectations, configuration ranges, and the requirement to test rendering changes on an iOS simulator and preferably physical hardware.

**Step 5: Expand `.gitignore`**

Cover `.DS_Store`, DerivedData, `.build`, `build`, result bundles, `xcuserdata`, `*.xcuserstate`, SwiftPM workspace state, and local capture/audit folders. Do not ignore `Package.resolved` globally if Example later needs reproducible external dependencies.

**Step 6: Audit the public tree**

Run:

```bash
rg -n "/Users/|macbook|DEVELOPMENT_TEAM = [A-Z0-9]+|com\\.codex|API[_-]?KEY|TOKEN|PASSWORD" . \
  -g '!*.xcuserstate' -g '!DerivedData' -g '!build'
git status --short --ignored
```

Expected: no personal path, personal signing team, old bundle identifier, or secret appears; ignored output contains only local/build artifacts.

**Step 7: Commit**

```bash
git add LICENSE ATTRIBUTIONS.md CONTRIBUTING.md CHANGELOG.md README.md .gitignore docs
git commit -m "docs: prepare public package documentation"
```

### Task 9: Add continuous integration

**Files:**
- Create: `.github/workflows/ci.yml`

**Step 1: Create the GitHub Actions workflow**

Use a macOS runner and perform three jobs or sequential steps:

- discover an available iPhone simulator dynamically;
- run the `BurningPaper` package tests;
- build the Example application with code signing disabled.

Core commands:

```bash
DEVICE_ID=$(xcrun simctl list devices available -j | \
  jq -r '[.devices[][] | select(.name | startswith("iPhone"))][0].udid')

xcodebuild test -scheme BurningPaper \
  -destination "platform=iOS Simulator,id=$DEVICE_ID"

xcodebuild build \
  -project Example/BurningPaperExample.xcodeproj \
  -scheme BurningPaperExample \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  CODE_SIGNING_ALLOWED=NO
```

Fail early if `DEVICE_ID` is empty. Pin the selected Xcode version only after checking which version is present on the chosen GitHub runner.

**Step 2: Validate the workflow locally**

Run the same shell steps locally. Expected: package tests pass and Example builds.

**Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: verify package and example app"
```

### Task 10: Perform release verification and prepare v0.1.0

**Files:**
- Modify if needed: `README.md`
- Modify if needed: `CHANGELOG.md`
- Verify: all package, Example, documentation, and license files

**Step 1: Run the complete automated verification**

Run:

```bash
xcodebuild test -scheme BurningPaper \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'

xcodebuild build -scheme BurningPaper \
  -destination 'generic/platform=iOS Simulator'

xcodebuild build \
  -project Example/BurningPaperExample.xcodeproj \
  -scheme BurningPaperExample \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project Example/BurningPaperExample.xcodeproj \
  -scheme BurningPaperExample \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: tests and all four build checks succeed.

**Step 2: Verify package metadata and public API**

Run:

```bash
swift package dump-package
git diff --check
git status --short
git log --oneline --decorate -12
```

Expected: platform is iOS 18, the library product is `BurningPaper`, no whitespace errors exist, and the working tree is clean.

**Step 3: Perform the physical-device visual pass**

Run the Example on the iPhone 16 Pro. Record a short clean demonstration showing intact paper, tap ignition, continuous drag ignition, varied active edge, revealed background, and reset.

Add only a compressed repository-friendly preview to `docs/media`; keep the original recording outside Git. Update README media links.

**Step 4: Replace the repository URL placeholder**

After the GitHub repository URL is known, update the Swift Package Manager instructions and any badges. Commit the final documentation adjustment.

**Step 5: Create the release candidate commit**

```bash
git add README.md CHANGELOG.md docs/media
git commit -m "release: prepare v0.1.0"
```

Skip the commit if verification caused no tracked changes.

**Step 6: Tag only after user approval**

```bash
git tag -a v0.1.0 -m "BurningPaper 0.1.0"
```

Do not push the repository or tag, create the public GitHub repository, or publish a release without explicit user approval and the final repository URL.
