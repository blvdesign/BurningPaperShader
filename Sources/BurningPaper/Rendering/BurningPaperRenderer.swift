import BurningPaperShaderTypes
import CoreGraphics
import Foundation
import MetalKit

struct BurningPaperTextureSize: Equatable {
    let width: Int
    let height: Int
}

enum BurningPaperStateTextureSizer {
    static func size(for drawableSize: CGSize, maxDimension: Int) -> BurningPaperTextureSize {
        guard drawableSize.width > 1, drawableSize.height > 1 else {
            return BurningPaperTextureSize(width: maxDimension, height: maxDimension)
        }

        if drawableSize.width >= drawableSize.height {
            let height = max(1, Int(round(CGFloat(maxDimension) * drawableSize.height / drawableSize.width)))
            return BurningPaperTextureSize(width: maxDimension, height: height)
        }

        let width = max(1, Int(round(CGFloat(maxDimension) * drawableSize.width / drawableSize.height)))
        return BurningPaperTextureSize(width: width, height: maxDimension)
    }
}

struct BurningPaperIgnitionQueue {
    static let maximumIgnitionsPerFrame = 18
    static let maximumIgnitionsPerBatch = BurnIgnitionPlanner.maximumIgnitionsPerPath
    static let maximumQueuedIgnitions = maximumIgnitionsPerBatch * 8

    private var batches: [[BurnIgnition]] = []

    var count: Int {
        batches.reduce(0) { $0 + $1.count }
    }

    mutating func enqueue(_ ignitions: [BurnIgnition]) {
        guard !ignitions.isEmpty else {
            return
        }

        for start in stride(from: 0, to: ignitions.count, by: Self.maximumIgnitionsPerBatch) {
            let end = min(start + Self.maximumIgnitionsPerBatch, ignitions.count)
            batches.append(Array(ignitions[start..<end]))
        }

        while count > Self.maximumQueuedIgnitions, batches.count > 1 {
            batches.removeFirst()
        }
    }

    mutating func drainFrame() -> [BurnIgnition] {
        var result: [BurnIgnition] = []
        var remainingCapacity = Self.maximumIgnitionsPerFrame

        while remainingCapacity > 0, !batches.isEmpty {
            let drainCount = min(remainingCapacity, batches[0].count)
            result.append(contentsOf: batches[0].prefix(drainCount))
            batches[0].removeFirst(drainCount)
            remainingCapacity -= drainCount

            if batches[0].isEmpty {
                batches.removeFirst()
            }
        }

        return result
    }

    mutating func removeAll() {
        batches.removeAll(keepingCapacity: true)
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

/// A low-level Metal renderer for the procedural burning-paper effect.
public final class BurningPaperRenderer: NSObject, MTKViewDelegate {
    /// Controls the visual appearance and propagation of the effect.
    public var configuration: BurningPaperConfiguration {
        get { storedConfiguration }
        set { storedConfiguration = newValue.sanitized }
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let computePipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState
    private var storedConfiguration = BurningPaperConfiguration.default.sanitized
    private var stateRead: MTLTexture?
    private var stateWrite: MTLTexture?
    private var startTime = CACurrentMediaTime()
    private var lastFrameTime = CACurrentMediaTime()
    private var pendingIgnitions = BurningPaperIgnitionQueue()
    private var shouldResetState = true
    private let maxStateTextureDimension = 1024
    private var stateTextureWidth = 0
    private var stateTextureHeight = 0

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

        var random = SystemRandomNumberGenerator()
        ignite(BurnIgnitionPlanner.ignitions(for: [point], random: &random))
    }

    /// Ignites the paper along a path of normalized coordinates.
    public func ignite(path normalizedPoints: [CGPoint]) {
        let points = normalizedPoints.compactMap(Self.normalized)
        guard !points.isEmpty else {
            return
        }

        var random = SystemRandomNumberGenerator()
        ignite(BurnIgnitionPlanner.ignitions(for: points, random: &random))
    }

    /// Restores the paper to its initial unburned state.
    public func reset() {
        shouldResetState = true
        pendingIgnitions.removeAll()
        startTime = CACurrentMediaTime()
        lastFrameTime = startTime
    }

    func ignite(_ burnIgnitions: [BurnIgnition]) {
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
        ensureStateTextures(for: size)
        shouldResetState = true
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let now = CACurrentMediaTime()
        let deltaTime = min(Float(now - lastFrameTime), 1.0 / 30.0)
        lastFrameTime = now

        ensureStateTextures(for: view.drawableSize)

        let time = Float(now - startTime)
        let ignitions = BurningPaperFrameIgnitionPolicy.takeIgnitions(
            from: &pendingIgnitions,
            isResetting: shouldResetState
        )
        let ignitionPasses: [BurnIgnition?] = shouldResetState ? [nil] : (ignitions.map(Optional.some) + [nil])

        for ignition in ignitionPasses {
            var uniforms = makeUniforms(
                time: time,
                deltaTime: deltaTime,
                viewSize: view.drawableSize,
                ignition: ignition
            )
            encodeComputePass(commandBuffer: commandBuffer, uniforms: &uniforms)
            swap(&stateRead, &stateWrite)
        }

        var renderUniforms = makeUniforms(
            time: time,
            deltaTime: deltaTime,
            viewSize: view.drawableSize,
            ignition: nil
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
        ignition: BurnIgnition?
    ) -> BurningPaperUniforms {
        let parameters = storedConfiguration
        var uniforms = BurningPaperUniforms()
        uniforms.textureSize = SIMD2(Float(stateTextureWidth), Float(stateTextureHeight))
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
        uniforms.resetState = shouldResetState ? 1 : 0
        uniforms.padding0 = 0
        uniforms.padding1 = 0
        uniforms.padding2 = 0
        return uniforms
    }

    private func ensureStateTextures(for drawableSize: CGSize) {
        let size = BurningPaperStateTextureSizer.size(
            for: drawableSize,
            maxDimension: maxStateTextureDimension
        )
        guard stateTextureWidth != size.width || stateTextureHeight != size.height || stateRead == nil else {
            return
        }

        stateTextureWidth = size.width
        stateTextureHeight = size.height
        makeStateTextures(width: size.width, height: size.height)
        shouldResetState = true
    }

    private func makeStateTextures(width: Int, height: Int) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        stateRead = device.makeTexture(descriptor: descriptor)
        stateWrite = device.makeTexture(descriptor: descriptor)
    }

    private func encodeComputePass(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout BurningPaperUniforms
    ) {
        guard let stateRead,
              let stateWrite,
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
            MTLSize(width: stateTextureWidth, height: stateTextureHeight, depth: 1),
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

        guard let stateRead,
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
}
