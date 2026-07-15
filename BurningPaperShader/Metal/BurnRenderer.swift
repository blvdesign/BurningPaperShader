import CoreGraphics
import MetalKit

final class BurnRenderer: NSObject, MTKViewDelegate {
    var parameters = BurnParameters.defaults.sanitized

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let computePipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState
    private var stateRead: MTLTexture?
    private var stateWrite: MTLTexture?
    private var startTime = CACurrentMediaTime()
    private var lastFrameTime = CACurrentMediaTime()
    private var pendingIgnitions: [PendingIgnition] = []
    private var shouldResetState = true
    private let maxStateTextureDimension = 1024
    private let maxIgnitionsPerFrame = 18
    private let maxQueuedIgnitions = 96
    private var stateTextureWidth = 0
    private var stateTextureHeight = 0

    private struct PendingIgnition {
        var normalizedPoint: CGPoint
        var radiusScale: Float
        var heatScale: Float
        var seed: Float
    }

    init?(device: MTLDevice, colorPixelFormat: MTLPixelFormat) {
        guard
            let commandQueue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary(),
            let computeFunction = library.makeFunction(name: "updateBurnState"),
            let vertexFunction = library.makeFunction(name: "fullscreenVertex"),
            let fragmentFunction = library.makeFunction(name: "paperFragment")
        else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        do {
            computePipeline = try device.makeComputePipelineState(function: computeFunction)

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
            renderPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }

        super.init()
    }

    func ignite(_ burnIgnitions: [BurnIgnition]) {
        let ignitions = burnIgnitions.map { ignition in
            PendingIgnition(
                normalizedPoint: CGPoint(
                    x: min(max(ignition.normalizedPoint.x, 0), 1),
                    y: min(max(ignition.normalizedPoint.y, 0), 1)
                ),
                radiusScale: min(max(ignition.radiusScale, 0.25), 2.2),
                heatScale: min(max(ignition.heatScale, 0.25), 2.0),
                seed: ignition.seed
            )
        }

        pendingIgnitions.append(contentsOf: ignitions)
        if pendingIgnitions.count > maxQueuedIgnitions {
            pendingIgnitions.removeFirst(pendingIgnitions.count - maxQueuedIgnitions)
        }
    }

    func reset() {
        shouldResetState = true
        pendingIgnitions.removeAll()
        startTime = CACurrentMediaTime()
        lastFrameTime = startTime
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        ensureStateTextures(for: size)
        shouldResetState = true
    }

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }

        let now = CACurrentMediaTime()
        let deltaTime = min(Float(now - lastFrameTime), 1.0 / 30.0)
        lastFrameTime = now

        ensureStateTextures(for: view.drawableSize)

        let time = Float(now - startTime)
        let ignitions = drainPendingIgnitions()
        let ignitionPasses: [PendingIgnition?] = shouldResetState ? [nil] : (ignitions.map(Optional.some) + [nil])

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
        ignition pendingIgnition: PendingIgnition?
    ) -> BurnUniforms {
        let ignitionPoint = pendingIgnition.map {
            SIMD2<Float>(Float($0.normalizedPoint.x), Float($0.normalizedPoint.y))
        } ?? SIMD2<Float>(-1, -1)
        let ignitionSeed = pendingIgnition?.seed ?? 0

        return BurnUniforms(
            textureSize: SIMD2<Float>(Float(stateTextureWidth), Float(stateTextureHeight)),
            viewSize: SIMD2<Float>(Float(viewSize.width), Float(viewSize.height)),
            time: time,
            deltaTime: deltaTime,
            ignitionPoint: ignitionPoint,
            ignitionRadius: parameters.ignitionRadius,
            ignitionSeed: ignitionSeed,
            ignitionRadiusScale: pendingIgnition?.radiusScale ?? 1,
            ignitionHeatScale: pendingIgnition?.heatScale ?? 1,
            hasIgnition: pendingIgnition == nil ? 0 : 1,
            burnSpeed: parameters.burnSpeed,
            spreadRate: parameters.spreadRate,
            coolingRate: parameters.coolingRate,
            edgeWidth: parameters.edgeWidth,
            stainWidth: parameters.stainWidth,
            charWidth: parameters.charWidth,
            glowAmount: parameters.glowAmount,
            noiseStrength: parameters.noiseStrength,
            frontComplexity: parameters.frontComplexity,
            ignitionVariance: parameters.ignitionVariance,
            flameAmount: parameters.flameAmount,
            paperWrinkleAmount: parameters.paperWrinkleAmount,
            smokeAmount: parameters.smokeAmount,
            emberAmount: parameters.emberAmount,
            resetState: shouldResetState ? 1 : 0
        )
    }

    private func drainPendingIgnitions() -> [PendingIgnition] {
        guard !pendingIgnitions.isEmpty else {
            return []
        }

        let count = min(maxIgnitionsPerFrame, pendingIgnitions.count)
        let ignitions = Array(pendingIgnitions.prefix(count))
        pendingIgnitions.removeFirst(count)
        return ignitions
    }

    private func ensureStateTextures(for drawableSize: CGSize) {
        let size = desiredStateTextureSize(for: drawableSize)
        guard stateTextureWidth != size.width || stateTextureHeight != size.height || stateRead == nil else {
            return
        }

        stateTextureWidth = size.width
        stateTextureHeight = size.height
        makeStateTextures(width: size.width, height: size.height)
        shouldResetState = true
    }

    private func desiredStateTextureSize(for drawableSize: CGSize) -> (width: Int, height: Int) {
        guard drawableSize.width > 1, drawableSize.height > 1 else {
            return (maxStateTextureDimension, maxStateTextureDimension)
        }

        if drawableSize.width >= drawableSize.height {
            let height = max(1, Int(round(CGFloat(maxStateTextureDimension) * drawableSize.height / drawableSize.width)))
            return (maxStateTextureDimension, height)
        }

        let width = max(1, Int(round(CGFloat(maxStateTextureDimension) * drawableSize.width / drawableSize.height)))
        return (width, maxStateTextureDimension)
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

    private func encodeComputePass(commandBuffer: MTLCommandBuffer, uniforms: inout BurnUniforms) {
        guard
            let stateRead,
            let stateWrite,
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return
        }

        encoder.setComputePipelineState(computePipeline)
        encoder.setTexture(stateRead, index: 0)
        encoder.setTexture(stateWrite, index: 1)
        encoder.setBytes(&uniforms, length: MemoryLayout<BurnUniforms>.stride, index: 0)

        let width = computePipeline.threadExecutionWidth
        let height = max(1, computePipeline.maxTotalThreadsPerThreadgroup / width)
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
        let threadsPerGrid = MTLSize(width: stateTextureWidth, height: stateTextureHeight, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
    }

    private func encodeRenderPass(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        drawable: MTLDrawable,
        uniforms: inout BurnUniforms
    ) {
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard
            let stateRead,
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        encoder.setRenderPipelineState(renderPipeline)
        encoder.setFragmentTexture(stateRead, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<BurnUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}
