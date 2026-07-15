# Burning Paper iOS MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS test app where a fullscreen paper layer burns away from a tap point and reveals a solid color background.

**Architecture:** SwiftUI owns app layout and touch input. A shared `MTKView` renderer owns persistent Metal textures for burn and heat state, updates them with a compute pass, and draws the paper material with char, stain, glow, and transparency in a render pass.

**Tech Stack:** Xcode 26.6, iOS 26.0 deployment target, SwiftUI, MetalKit, Metal compute/render shaders, XCTest.

---

### Task 1: Project Skeleton And Parameters

**Files:**
- Create: `BurningPaperShader.xcodeproj/project.pbxproj`
- Create: `BurningPaperShader/App/BurningPaperShaderApp.swift`
- Create: `BurningPaperShader/App/ContentView.swift`
- Create: `BurningPaperShader/Metal/BurnParameters.swift`
- Create: `BurningPaperShaderTests/BurnParametersTests.swift`

- [x] **Step 1: Write the failing parameter test**

```swift
import XCTest
@testable import BurningPaperShader

final class BurnParametersTests: XCTestCase {
    func testSanitizedClampsUnsafeValues() {
        let unsafe = BurnParameters(
            burnSpeed: -1,
            spreadRate: 10,
            coolingRate: -2,
            ignitionRadius: 1,
            edgeWidth: -0.1,
            stainWidth: 2,
            charWidth: -0.5,
            glowAmount: 5,
            noiseStrength: -3
        )

        let safe = unsafe.sanitized

        XCTAssertEqual(safe.burnSpeed, 0.01)
        XCTAssertEqual(safe.spreadRate, 3.0)
        XCTAssertEqual(safe.coolingRate, 0.0)
        XCTAssertEqual(safe.ignitionRadius, 0.2)
        XCTAssertEqual(safe.edgeWidth, 0.001)
        XCTAssertEqual(safe.stainWidth, 0.25)
        XCTAssertEqual(safe.charWidth, 0.001)
        XCTAssertEqual(safe.glowAmount, 1.0)
        XCTAssertEqual(safe.noiseStrength, 0.0)
    }
}
```

- [x] **Step 2: Implement `BurnParameters`**

`BurnParameters` contains defaults and clamps values before they are sent to Metal.

- [x] **Step 3: Add SwiftUI app shell**

The shell shows a solid background and a fullscreen Metal paper renderer.

### Task 2: Metal Renderer

**Files:**
- Create: `BurningPaperShader/Metal/MetalView.swift`
- Create: `BurningPaperShader/Metal/BurnRenderer.swift`
- Create: `BurningPaperShader/Metal/ShaderTypes.swift`
- Create: `BurningPaperShader/Metal/Shaders.metal`

- [x] **Step 1: Add `MTKView` wrapper**

SwiftUI passes tap triggers and live parameters into the renderer.

- [x] **Step 2: Add renderer pipelines**

The renderer creates persistent burn and heat textures, runs `updateBurnState`, then draws a fullscreen triangle with `paperFragment`.

- [x] **Step 3: Add shaders**

The compute shader spreads heat and irreversible burn state. The render shader converts state into transparent void, dark char edge, brown stain, subtle paper grain, and a restrained amber glow.

### Task 3: Verification

**Files:**
- Modify as needed based on compiler feedback.

- [x] **Step 1: Run unit tests**

Run: `xcodebuild test -project BurningPaperShader.xcodeproj -scheme BurningPaperShader -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

Result: passed on the available iOS 26.5 simulator.

- [x] **Step 2: Build for simulator**

Run: `xcodebuild build -project BurningPaperShader.xcodeproj -scheme BurningPaperShader -destination 'generic/platform=iOS Simulator'`

- [x] **Step 3: Confirm device-readiness**

Run: `xcodebuild build -project BurningPaperShader.xcodeproj -scheme BurningPaperShader -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`

Result: passed for arm64 iOS. To install on the physical iPhone, open the project in Xcode, select the iPhone 16 Pro, choose a signing team if Xcode asks, and run.
