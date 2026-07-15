#ifndef BURNING_PAPER_SHADER_TYPES_H
#define BURNING_PAPER_SHADER_TYPES_H

#include <simd/simd.h>

#ifdef __METAL_VERSION__
typedef uint BurningPaperUInt32;
#else
#include <stdint.h>
typedef uint32_t BurningPaperUInt32;
#endif

typedef struct BurningPaperUniforms {
    vector_float2 textureSize;
    vector_float2 viewSize;
    vector_float4 paperColor;
    float time;
    float deltaTime;
    vector_float2 ignitionPoint;
    float ignitionRadius;
    float ignitionSeed;
    float ignitionRadiusScale;
    float ignitionHeatScale;
    BurningPaperUInt32 hasIgnition;
    float burnSpeed;
    float spreadRate;
    float coolingRate;
    float edgeWidth;
    float stainWidth;
    float charWidth;
    float glowAmount;
    float noiseStrength;
    float frontComplexity;
    float ignitionVariance;
    float flameAmount;
    float paperWrinkleAmount;
    float smokeAmount;
    float emberAmount;
    BurningPaperUInt32 resetState;
    BurningPaperUInt32 padding0;
    BurningPaperUInt32 padding1;
    BurningPaperUInt32 padding2;
} BurningPaperUniforms;

#endif /* BURNING_PAPER_SHADER_TYPES_H */
