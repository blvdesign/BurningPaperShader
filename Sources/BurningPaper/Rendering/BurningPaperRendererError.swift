import Foundation

/// Describes a failure while creating the Metal burning-paper renderer.
public enum BurningPaperRendererError: Error, Equatable, LocalizedError, Sendable {
    /// Metal could not create a command queue for the selected device.
    case commandQueueCreationFailed

    /// The precompiled Metal library could not be loaded from the Swift package.
    case shaderLibraryLoadingFailed(reason: String)

    /// A required Metal function is absent from the package library.
    case shaderFunctionMissing(name: String)

    /// Metal could not create the compute pipeline.
    case computePipelineCreationFailed(reason: String)

    /// Metal could not create the render pipeline.
    case renderPipelineCreationFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .commandQueueCreationFailed:
            "Unable to create a Metal command queue."
        case let .shaderLibraryLoadingFailed(reason):
            "Unable to load the BurningPaper package Metal library: \(reason)"
        case let .shaderFunctionMissing(name):
            "The BurningPaper Metal function '\(name)' is missing from the package library."
        case let .computePipelineCreationFailed(reason):
            "Unable to create the BurningPaper compute pipeline: \(reason)"
        case let .renderPipelineCreationFailed(reason):
            "Unable to create the BurningPaper render pipeline: \(reason)"
        }
    }
}
