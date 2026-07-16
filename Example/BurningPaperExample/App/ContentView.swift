import BurningPaper
import SwiftUI

struct ContentView: View {
    @StateObject private var controller = BurningPaperController()
    @State private var configuration = BurningPaperConfiguration.default
    @State private var showsDebugControls = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AbstractBackgroundView()
                .ignoresSafeArea()

            BurningPaperView(
                controller: controller,
                configuration: configuration
            )
            .ignoresSafeArea()

            overlayControls
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
        .statusBarHidden(true)
    }

    private var overlayControls: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    controller.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Reset paper")

                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        showsDebugControls.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Toggle tuning controls")
            }
            .buttonStyle(.bordered)

            if showsDebugControls {
                debugControls
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
            }
        }
    }

    private var debugControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledSlider("Burn", value: binding(\.burnSpeed), range: 0.1...2.0)
            labeledSlider("Paper", value: binding(\.noiseStrength), range: 0.0...1.0)
            labeledSlider("Front", value: binding(\.frontComplexity), range: 0.0...1.0)
            labeledSlider("Var", value: binding(\.ignitionVariance), range: 0.0...1.0)
            labeledSlider("Flame", value: binding(\.flameAmount), range: 0.0...1.0)
            labeledSlider("Wrink", value: binding(\.paperWrinkleAmount), range: 0.0...1.0)
            labeledSlider("Smoke", value: binding(\.smokeAmount), range: 0.0...0.55)
            labeledSlider("Ember", value: binding(\.emberAmount), range: 0.0...0.45)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func labeledSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            Slider(value: value, in: range)
                .frame(width: 132)
        }
    }

    private func binding(
        _ keyPath: WritableKeyPath<BurningPaperConfiguration, Float>
    ) -> Binding<Double> {
        Binding<Double>(
            get: { Double(configuration[keyPath: keyPath]) },
            set: { configuration[keyPath: keyPath] = Float($0) }
        )
    }
}

private struct AbstractBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            Image("AbstractBurnBackdrop")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay(Color.black.opacity(0.04))
                .clipped()
        }
    }
}
