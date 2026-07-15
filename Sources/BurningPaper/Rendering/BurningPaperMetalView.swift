import CoreGraphics
import MetalKit
import SwiftUI
import UIKit

protocol BurningPaperRendering: AnyObject {
    var configuration: BurningPaperConfiguration { get set }

    func ignite(path: [CGPoint])
    func ignite(_ ignitions: [BurnIgnition])
    func reset()
}

extension BurningPaperRenderer: BurningPaperRendering {}

private enum BurningPaperMetalViewError: Error {
    case metalDeviceUnavailable
}

@MainActor
struct BurningPaperMetalView: UIViewRepresentable {
    let controller: BurningPaperController
    let configuration: BurningPaperConfiguration
    let interaction: BurningPaperViewState
    let commandRevision: UInt64
    let interactionRevision: UInt64

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        Self.configure(view)
        context.coordinator.installRenderer(in: view, configuration: configuration)
        context.coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: configuration,
            fallbackView: view
        )
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        _ = commandRevision
        _ = interactionRevision
        context.coordinator.update(
            controller: controller,
            interaction: interaction,
            configuration: configuration,
            fallbackView: view
        )
    }

    static func configure(_ view: MTKView) {
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.preferredFramesPerSecond = 120
        view.enableSetNeedsDisplay = false
        view.isPaused = false
    }

    @MainActor
    final class Coordinator {
        typealias RendererFactory = (MTLDevice, MTLPixelFormat) throws -> any BurningPaperRendering

        var renderer: (any BurningPaperRendering)?
        private(set) var rendererInitializationError: Error?

        private let rendererFactory: RendererFactory

        init(
            rendererFactory: @escaping RendererFactory = { device, pixelFormat in
                try BurningPaperRenderer(device: device, colorPixelFormat: pixelFormat)
            }
        ) {
            self.rendererFactory = rendererFactory
        }

        func installRenderer(in view: MTKView, configuration: BurningPaperConfiguration) {
            do {
                guard let device = view.device else {
                    throw BurningPaperMetalViewError.metalDeviceUnavailable
                }

                let renderer = try rendererFactory(device, view.colorPixelFormat)
                renderer.configuration = configuration
                self.renderer = renderer
                view.delegate = renderer as? MTKViewDelegate
            } catch {
                rendererInitializationError = error
                renderer = nil
                view.delegate = nil
                applyFallback(to: view, configuration: configuration)
            }
        }

        func update(
            controller: BurningPaperController,
            interaction: BurningPaperViewState,
            configuration: BurningPaperConfiguration,
            fallbackView: MTKView? = nil
        ) {
            renderer?.configuration = configuration

            for command in controller.drainPendingCommands() {
                switch command.kind {
                case let .ignite(points):
                    renderer?.ignite(path: points)
                case .reset:
                    interaction.clearPendingIgnitions()
                    renderer?.reset()
                }
            }

            for ignitions in interaction.drainPendingIgnitions() {
                renderer?.ignite(ignitions)
            }

            if renderer == nil, rendererInitializationError != nil, let fallbackView {
                applyFallback(to: fallbackView, configuration: configuration)
            }
        }

        private func applyFallback(
            to view: MTKView,
            configuration: BurningPaperConfiguration
        ) {
            let color = configuration.sanitized.paperColor
            view.isOpaque = true
            view.backgroundColor = UIColor(
                red: CGFloat(color.red),
                green: CGFloat(color.green),
                blue: CGFloat(color.blue),
                alpha: 1
            )
            view.clearColor = MTLClearColor(
                red: Double(color.red),
                green: Double(color.green),
                blue: Double(color.blue),
                alpha: 1
            )
        }
    }
}
