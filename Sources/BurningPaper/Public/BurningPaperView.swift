import CoreGraphics
import SwiftUI

@MainActor
final class BurningPaperViewState: ObservableObject {
    private weak var controller: BurningPaperController?
    private var isInteractive = true
    private var lastDragPoint: CGPoint?
    private var observedResetRevision: UInt64
    private var random: SeededRandomNumberGenerator

    init(
        controller: BurningPaperController,
        seed: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) {
        self.controller = controller
        observedResetRevision = controller.resetRevision
        random = SeededRandomNumberGenerator(seed: seed)
    }

    func bind(to controller: BurningPaperController) {
        guard self.controller !== controller else {
            return
        }

        self.controller = controller
        observedResetRevision = controller.resetRevision
        lastDragPoint = nil
    }

    func setInteractive(_ isInteractive: Bool) {
        self.isInteractive = isInteractive
        if !isInteractive {
            lastDragPoint = nil
        }
    }

    func dragChanged(location: CGPoint, in size: CGSize) {
        guard prepareForDrag() else { return }
        planIgnitions(to: location, in: size)
    }

    func dragEnded(location: CGPoint, in size: CGSize) {
        guard prepareForDrag() else {
            lastDragPoint = nil
            return
        }

        planIgnitions(to: location, in: size)
        lastDragPoint = nil
    }

    func resetDragState() {
        lastDragPoint = nil
        observedResetRevision = controller?.resetRevision ?? observedResetRevision
    }

    private func prepareForDrag() -> Bool {
        guard isInteractive, let controller else {
            return false
        }

        if observedResetRevision != controller.resetRevision {
            lastDragPoint = nil
            observedResetRevision = controller.resetRevision
        }
        return true
    }

    private func planIgnitions(to location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0,
              size.width.isFinite, size.height.isFinite,
              location.x.isFinite, location.y.isFinite else {
            return
        }

        let point = CGPoint(
            x: min(max(location.x / size.width, 0), 1),
            y: min(max(location.y / size.height, 0), 1)
        )
        let ignitions = BurnIgnitionPlanner.ignitions(
            from: lastDragPoint,
            to: point,
            random: &random
        )
        lastDragPoint = point

        guard !ignitions.isEmpty else {
            return
        }

        controller?.ignite(ignitions)
    }
}

/// A SwiftUI surface that renders and optionally interacts with burning paper.
///
/// Each view requires its own ``BurningPaperController``. Sharing one controller
/// between multiple views is unsupported because command delivery is one-to-one.
@MainActor
public struct BurningPaperView: View {
    @ObservedObject private var controller: BurningPaperController
    @StateObject private var interaction: BurningPaperViewState

    private let configuration: BurningPaperConfiguration
    private let isInteractive: Bool

    /// Creates a burning-paper surface driven by its dedicated controller.
    public init(
        controller: BurningPaperController,
        configuration: BurningPaperConfiguration = .default,
        isInteractive: Bool = true
    ) {
        _controller = ObservedObject(wrappedValue: controller)
        _interaction = StateObject(
            wrappedValue: BurningPaperViewState(controller: controller)
        )
        self.configuration = configuration
        self.isInteractive = isInteractive
    }

    public var body: some View {
        GeometryReader { proxy in
            if isInteractive {
                metalView
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                interaction.dragChanged(
                                    location: value.location,
                                    in: proxy.size
                                )
                            }
                            .onEnded { value in
                                interaction.dragEnded(
                                    location: value.location,
                                    in: proxy.size
                                )
                            }
                    )
            } else {
                metalView
            }
        }
    }

    private var metalView: some View {
        BurningPaperMetalView(
            controller: controller,
            configuration: configuration,
            interaction: interaction,
            isInteractive: isInteractive,
            commandRevision: controller.commandRevision
        )
    }
}
