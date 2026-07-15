# Burning Paper Shader

Native iOS prototype for a fullscreen paper burn effect. The app uses SwiftUI for layout and input, plus MetalKit for a persistent multi-channel burn simulation.

## Requirements

- Xcode 26.6
- iOS 26 SDK
- Metal Toolchain component installed in Xcode
- iPhone with Developer Mode enabled for device runs

## Run

1. Open `BurningPaperShader.xcodeproj` in Xcode.
2. Select the `BurningPaperShader` scheme.
3. Select your iPhone.
4. If Xcode asks, choose your Apple Account team under Signing & Capabilities.
5. Press Run.

The app starts as a fullscreen paper layer over an abstract image background. Tap or drag anywhere to ignite irregular burn clusters along the touched path.

Controls:

- Counter-clockwise arrow: reset the paper.
- Sliders icon: show or hide tuning controls.
- Burn: propagation speed.
- Paper: paper resistance and fiber variation.
- Front: raggedness and complexity of the active burn edge.
- Var: per-tap ignition shape variation.
- Flame: red/orange heat and small flame hints along the active edge.
- Wrink: crumpled paper texture intensity.
- Smoke: subtle grey smoke/ash veil on the active edge.
- Ember: sparse amber flecks on the active edge.

The burn state is stored as material channels: damage, heat, char, and ash. This lets the shader age the edge from hot rim to dark char and dusty ash instead of rendering a single uniform outline.

## Verify From Terminal

```sh
xcodebuild build-for-testing -project BurningPaperShader.xcodeproj -scheme BurningPaperShader -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild test-without-building -project BurningPaperShader.xcodeproj -scheme BurningPaperShader -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild build -project BurningPaperShader.xcodeproj -scheme BurningPaperShader -destination 'generic/platform=iOS Simulator'
xcodebuild build -project BurningPaperShader.xcodeproj -scheme BurningPaperShader -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

The physical iPhone may appear offline until it is unlocked, trusted, paired in Xcode Device Hub, and Developer Mode is enabled.
