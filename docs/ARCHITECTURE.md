# Architecture

BurningPaper separates its public interaction API from a persistent Metal
simulation. A consumer can use the SwiftUI surface or host the renderer in a
custom `MTKView` integration.

## Rendering flow

1. `BurningPaperView` receives gestures and commands from
   `BurningPaperController`.
2. Gesture paths and controller paths are converted to bounded normalized
   ignition points.
3. `BurningPaperRenderer` drains a limited number of queued ignitions for each
   frame.
4. The `updateBurnState` compute function advances persistent material state.
5. The `paperFragment` render function draws procedural paper, active edges,
   char, ash, smoke, embers, and transparency.

Configuration updates are sanitized on the CPU and copied into the shared
uniform structure before encoding GPU work. Controller coordinates are in the
`0...1` range, so commands do not depend on the rendered view size.

## GPU state

The simulation uses two `.rgba16Float` textures in a ping-pong arrangement.
Their channels hold burn damage, heat, char amount, and ash age. The compute
pass reads the current texture and writes the next texture, then the renderer
swaps them. This keeps evolving state on the GPU and avoids per-frame readback.

State textures preserve the drawable's aspect ratio and are downscaled when
needed so their longest dimension does not exceed 1024 pixels. A resize creates
fresh state, so resizing an active surface resets its simulation.

## Input and frame bounds

Tap and drag gestures are planned into ignition samples before reaching the
renderer. The pending queue is capped, long batches are downsampled, and only a
bounded number of ignitions are encoded per frame. A reset clears pending work
and restores unburned state before propagation resumes.

These limits prevent a fast gesture burst from turning into persistent input
latency. They also make frame cost more predictable, although visual and GPU
testing remains important when changing ignition density or shader work.

## Package resources

Metal source belongs to the `BurningPaper` target. Swift Package Manager
compiles it into the package's default Metal library, which the renderer loads
from `Bundle.module`. Host applications do not need to copy shader files or
look for functions in their own default library.

Swift and Metal share uniform definitions through `BurningPaperShaderTypes`.
Field order and alignment are part of the renderer ABI and are covered by
tests; changing one side without the other can compile and still corrupt
rendering.

## Failure behavior

The lower-level renderer throws `BurningPaperRendererError` when command queue,
shader library, function, or pipeline creation fails. The SwiftUI bridge owns
the package's normal view lifecycle and keeps simulation instances independent.

## Source map

- `Public`: consumer-facing view, controller, configuration, and color types
- `Rendering`: renderer, Metal view bridge, resource loading, and frame policy
- `Simulation`: normalized ignition representation and path planning
- `Shaders`: persistent-state compute and procedural render functions
- `BurningPaperShaderTypes`: shared CPU/GPU uniform ABI
