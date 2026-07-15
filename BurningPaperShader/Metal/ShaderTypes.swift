import simd

struct BurnUniforms {
    var textureSize: SIMD2<Float>
    var viewSize: SIMD2<Float>
    var time: Float
    var deltaTime: Float
    var ignitionPoint: SIMD2<Float>
    var ignitionRadius: Float
    var ignitionSeed: Float
    var ignitionRadiusScale: Float
    var ignitionHeatScale: Float
    var hasIgnition: UInt32
    var burnSpeed: Float
    var spreadRate: Float
    var coolingRate: Float
    var edgeWidth: Float
    var stainWidth: Float
    var charWidth: Float
    var glowAmount: Float
    var noiseStrength: Float
    var frontComplexity: Float
    var ignitionVariance: Float
    var flameAmount: Float
    var paperWrinkleAmount: Float
    var smokeAmount: Float
    var emberAmount: Float
    var resetState: UInt32
    var padding0: UInt32 = 0
    var padding1: UInt32 = 0
    var padding2: UInt32 = 0
}
