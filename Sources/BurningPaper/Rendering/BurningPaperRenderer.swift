import BurningPaperShaderTypes
import CoreGraphics
import Foundation
import MetalKit

struct BurningPaperTextureSize: Equatable {
    let width: Int
    let height: Int
}

enum BurningPaperStateTextureSizer {
    static func size(for drawableSize: CGSize, maxDimension: Int) -> BurningPaperTextureSize? {
        guard drawableSize.width.isFinite,
              drawableSize.height.isFinite,
              drawableSize.width > 0,
              drawableSize.height > 0,
              maxDimension > 0 else {
            return nil
        }

        let scale = min(1, CGFloat(maxDimension) / max(drawableSize.width, drawableSize.height))
        return BurningPaperTextureSize(
            width: max(1, Int(round(drawableSize.width * scale))),
            height: max(1, Int(round(drawableSize.height * scale)))
        )
    }
}

struct BurningPaperTextureState<Texture> {
    private(set) var read: Texture?
    private(set) var write: Texture?
    private(set) var size: BurningPaperTextureSize?

    var isAllocated: Bool {
        read != nil && write != nil && size != nil
    }

    mutating func replace(
        size: BurningPaperTextureSize,
        makeTexture: () -> Texture?
    ) -> Bool {
        guard let newRead = makeTexture(), let newWrite = makeTexture() else {
            return false
        }

        read = newRead
        write = newWrite
        self.size = size
        return true
    }

    mutating func swap() {
        Swift.swap(&read, &write)
    }
}

struct BurningPaperIgnitionQueue {
    static let maximumIgnitionsPerFrame = 18
    static let maximumQueuedIgnitions = 96

    private var pending: [BurnIgnition] = []

    var count: Int {
        pending.count
    }

    mutating func enqueue(_ ignitions: [BurnIgnition]) {
        guard !ignitions.isEmpty else {
            return
        }

        let newestBatch = Self.evenlyDownsampled(
            ignitions,
            maximumCount: Self.maximumQueuedIgnitions
        )
        if pending.count + newestBatch.count > Self.maximumQueuedIgnitions {
            pending = newestBatch
        } else {
            pending.append(contentsOf: newestBatch)
        }
    }

    mutating func drainFrame() -> [BurnIgnition] {
        let drainCount = min(Self.maximumIgnitionsPerFrame, pending.count)
        let result = Array(pending.prefix(drainCount))
        pending.removeFirst(drainCount)
        return result
    }

    mutating func removeAll() {
        pending.removeAll(keepingCapacity: true)
    }

    private static func evenlyDownsampled(
        _ ignitions: [BurnIgnition],
        maximumCount: Int
    ) -> [BurnIgnition] {
        guard ignitions.count > maximumCount else {
            return ignitions
        }

        let lastIndex = ignitions.count - 1
        return (0..<maximumCount).map { sampleIndex in
            let position = Double(sampleIndex) * Double(lastIndex) / Double(maximumCount - 1)
            return ignitions[Int(position.rounded())]
        }
    }
}

enum BurningPaperFrameIgnitionPolicy {
    static func takeIgnitions(
        from queue: inout BurningPaperIgnitionQueue,
        isResetting: Bool
    ) -> [BurnIgnition] {
        guard !isResetting else {
            return []
        }

        return queue.drainFrame()
    }
}

struct BurningPaperSimulationStep {
    let ignition: BurnIgnition?
    let deltaTime: Float
    let resetsState: Bool
}

enum BurningPaperSimulationStepPolicy {
    static func steps(
        ignitions: [BurnIgnition],
        frameDeltaTime: Float,
        isResetting: Bool
    ) -> [BurningPaperSimulationStep] {
        if isResetting {
            return [
                BurningPaperSimulationStep(ignition: nil, deltaTime: 0, resetsState: true),
                BurningPaperSimulationStep(
                    ignition: nil,
                    deltaTime: frameDeltaTime,
                    resetsState: false
                )
            ]
        }

        let injectionSteps = ignitions.map {
            BurningPaperSimulationStep(ignition: $0, deltaTime: 0, resetsState: false)
        }
        return injectionSteps + [
            BurningPaperSimulationStep(
                ignition: nil,
                deltaTime: frameDeltaTime,
                resetsState: false
            )
        ]
    }
}

/// A low-level Metal renderer for the procedural burning-paper effect.
///
/// The delegated `MTKView` must use the same device and color pixel format
/// supplied to the initializer, and its `sampleCount` must remain `1`. Use
/// ``isCompatible(with:)`` before assigning the renderer to a custom view.
public final class BurningPaperRenderer: NSObject, MTKViewDelegate {
    /// Controls the visual appearance and propagation of the effect.
    public var configuration: BurningPaperConfiguration {
        get { withStateLock { storedConfiguration } }
        set { withStateLock { storedConfiguration = newValue.sanitized } }
    }

    private let device: MTLDevice
    private let colorPixelFormat: MTLPixelFormat
    private let commandQueue: MTLCommandQueue
    private let computePipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState
    private let stateLock = NSLock()
    private var storedConfiguration = BurningPaperConfiguration.default.sanitized
    private var textureState = BurningPaperTextureState<MTLTexture>()
    private var startTime = CACurrentMediaTime()
    private var lastFrameTime = CACurrentMediaTime()
    private var pendingIgnitions = BurningPaperIgnitionQueue()
    private var shouldResetState = true
    private let maxStateTextureDimension = 1024

    /// Creates a renderer using the precompiled Metal library bundled with this package.
    public init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw BurningPaperRendererError.commandQueueCreationFailed
        }

        let library: MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            throw BurningPaperRendererError.shaderLibraryLoadingFailed(reason: error.localizedDescription)
        }

        guard let computeFunction = library.makeFunction(name: "updateBurnState") else {
            throw BurningPaperRendererError.shaderFunctionMissing(name: "updateBurnState")
        }
        guard let vertexFunction = library.makeFunction(name: "fullscreenVertex") else {
            throw BurningPaperRendererError.shaderFunctionMissing(name: "fullscreenVertex")
        }
        guard let fragmentFunction = library.makeFunction(name: "paperFragment") else {
            throw BurningPaperRendererError.shaderFunctionMissing(name: "paperFragment")
        }

        let computePipeline: MTLComputePipelineState
        do {
            computePipeline = try device.makeComputePipelineState(function: computeFunction)
        } catch {
            throw BurningPaperRendererError.computePipelineCreationFailed(reason: error.localizedDescription)
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let renderPipeline: MTLRenderPipelineState
        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw BurningPaperRendererError.renderPipelineCreationFailed(reason: error.localizedDescription)
        }

        self.device = device
        self.colorPixelFormat = colorPixelFormat
        self.commandQueue = commandQueue
        self.computePipeline = computePipeline
        self.renderPipeline = renderPipeline
        super.init()
    }

    /// Ignites the paper at a normalized coordinate in the `0...1` range.
    public func ignite(at normalizedPoint: CGPoint) {
        guard let point = Self.normalized(normalizedPoint) else {
            return
        }

        withStateLock {
            var random = SystemRandomNumberGenerator()
            enqueueLocked(BurnIgnitionPlanner.ignitions(for: [point], random: &random))
        }
    }

    /// Ignites the paper along a path of normalized coordinates.
    public func ignite(path normalizedPoints: [CGPoint]) {
        let points = normalizedPoints.compactMap(Self.normalized)
        guard !points.isEmpty else {
            return
        }

        withStateLock {
            var random = SystemRandomNumberGenerator()
            enqueueLocked(BurnIgnitionPlanner.ignitions(for: points, random: &random))
        }
    }

    /// Restores the paper to its initial unburned state.
    public func reset() {
        withStateLock {
            shouldResetState = true
            pendingIgnitions.removeAll()
            startTime = CACurrentMediaTime()
            lastFrameTime = startTime
        }
    }

    func ignite(_ burnIgnitions: [BurnIgnition]) {
        withStateLock {
            enqueueLocked(burnIgnitions)
        }
    }

    private func enqueueLocked(_ burnIgnitions: [BurnIgnition]) {
        let sanitized = burnIgnitions.compactMap { ignition -> BurnIgnition? in
            guard let point = Self.normalized(ignition.normalizedPoint),
                  ignition.radiusScale.isFinite,
                  ignition.heatScale.isFinite,
                  ignition.seed.isFinite else {
                return nil
            }

            return BurnIgnition(
                normalizedPoint: point,
                radiusScale: min(max(ignition.radiusScale, 0.25), 2.2),
                heatScale: min(max(ignition.heatScale, 0.25), 2.0),
                seed: ignition.seed
            )
        }
        pendingIgnitions.enqueue(sanitized)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        withStateLock {
            guard isCompatible(with: view) else {
                return
            }
            _ = ensureStateTextures(for: size)
        }
    }

    public func draw(in view: MTKView) {
        withStateLock {
            drawLocked(in: view)
        }
    }

    /// Returns whether a Metal view satisfies this renderer's pipeline contract.
    public func isCompatible(with view: MTKView) -> Bool {
        guard let viewDevice = view.device else {
            return false
        }

        return (viewDevice as AnyObject) === (device as AnyObject) &&
            view.colorPixelFormat == colorPixelFormat &&
            view.sampleCount == 1
    }

    private func drawLocked(in view: MTKView) {
        guard isCompatible(with: view),
              ensureStateTextures(for: view.drawableSize),
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let now = CACurrentMediaTime()
        let deltaTime = min(Float(now - lastFrameTime), 1.0 / 30.0)
        lastFrameTime = now

        let time = Float(now - startTime)
        let ignitions = BurningPaperFrameIgnitionPolicy.takeIgnitions(
            from: &pendingIgnitions,
            isResetting: shouldResetState
        )
        let steps = BurningPaperSimulationStepPolicy.steps(
            ignitions: ignitions,
            frameDeltaTime: deltaTime,
            isResetting: shouldResetState
        )

        for step in steps {
            var uniforms = makeUniforms(
                time: time,
                deltaTime: step.deltaTime,
                viewSize: view.drawableSize,
                ignition: step.ignition,
                resetState: step.resetsState
            )
            encodeComputePass(commandBuffer: commandBuffer, uniforms: &uniforms)
            textureState.swap()
        }

        var renderUniforms = makeUniforms(
            time: time,
            deltaTime: deltaTime,
            viewSize: view.drawableSize,
            ignition: nil,
            resetState: false
        )
        encodeRenderPass(
            commandBuffer: commandBuffer,
            renderPassDescriptor: renderPassDescriptor,
            drawable: drawable,
            uniforms: &renderUniforms
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
        shouldResetState = false
    }

    private func makeUniforms(
        time: Float,
        deltaTime: Float,
        viewSize: CGSize,
        ignition: BurnIgnition?,
        resetState: Bool
    ) -> BurningPaperUniforms {
        let parameters = storedConfiguration
        let textureSize = textureState.size ?? BurningPaperTextureSize(width: 0, height: 0)
        var uniforms = BurningPaperUniforms()
        uniforms.textureSize = SIMD2(Float(textureSize.width), Float(textureSize.height))
        uniforms.viewSize = SIMD2(Float(viewSize.width), Float(viewSize.height))
        uniforms.paperColor = SIMD4(
            parameters.paperColor.red,
            parameters.paperColor.green,
            parameters.paperColor.blue,
            parameters.paperColor.alpha
        )
        uniforms.time = time
        uniforms.deltaTime = deltaTime
        uniforms.ignitionPoint = ignition.map {
            SIMD2(Float($0.normalizedPoint.x), Float($0.normalizedPoint.y))
        } ?? SIMD2(-1, -1)
        uniforms.ignitionRadius = parameters.ignitionRadius
        uniforms.ignitionSeed = ignition?.seed ?? 0
        uniforms.ignitionRadiusScale = ignition?.radiusScale ?? 1
        uniforms.ignitionHeatScale = ignition?.heatScale ?? 1
        uniforms.hasIgnition = ignition == nil ? 0 : 1
        uniforms.burnSpeed = parameters.burnSpeed
        uniforms.spreadRate = parameters.spreadRate
        uniforms.coolingRate = parameters.coolingRate
        uniforms.edgeWidth = parameters.edgeWidth
        uniforms.stainWidth = parameters.stainWidth
        uniforms.charWidth = parameters.charWidth
        uniforms.glowAmount = parameters.glowAmount
        uniforms.noiseStrength = parameters.noiseStrength
        uniforms.frontComplexity = parameters.frontComplexity
        uniforms.ignitionVariance = parameters.ignitionVariance
        uniforms.flameAmount = parameters.flameAmount
        uniforms.paperWrinkleAmount = parameters.paperWrinkleAmount
        uniforms.smokeAmount = parameters.smokeAmount
        uniforms.emberAmount = parameters.emberAmount
        uniforms.resetState = resetState ? 1 : 0
        uniforms.padding0 = 0
        uniforms.padding1 = 0
        uniforms.padding2 = 0
        return uniforms
    }

    private func ensureStateTextures(for drawableSize: CGSize) -> Bool {
        guard let size = BurningPaperStateTextureSizer.size(
            for: drawableSize,
            maxDimension: maxStateTextureDimension
        ) else {
            return textureState.isAllocated
        }

        guard textureState.size != size || !textureState.isAllocated else {
            return true
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: size.width,
            height: size.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        let replaced = textureState.replace(size: size) {
            device.makeTexture(descriptor: descriptor)
        }
        if replaced {
            shouldResetState = true
        }
        return textureState.isAllocated
    }

    private func encodeComputePass(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout BurningPaperUniforms
    ) {
        guard let stateRead = textureState.read,
              let stateWrite = textureState.write,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        encoder.setComputePipelineState(computePipeline)
        encoder.setTexture(stateRead, index: 0)
        encoder.setTexture(stateWrite, index: 1)
        encoder.setBytes(&uniforms, length: MemoryLayout<BurningPaperUniforms>.stride, index: 0)

        let width = computePipeline.threadExecutionWidth
        let height = max(1, computePipeline.maxTotalThreadsPerThreadgroup / width)
        encoder.dispatchThreads(
            MTLSize(width: stateRead.width, height: stateRead.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: height, depth: 1)
        )
        encoder.endEncoding()
    }

    private func encodeRenderPass(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        drawable: MTLDrawable,
        uniforms: inout BurningPaperUniforms
    ) {
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let stateRead = textureState.read,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        encoder.setRenderPipelineState(renderPipeline)
        encoder.setFragmentTexture(stateRead, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<BurningPaperUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private static func normalized(_ point: CGPoint) -> CGPoint? {
        guard point.x.isFinite, point.y.isFinite else {
            return nil
        }

        return CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }

    private func withStateLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body()
    }
}
