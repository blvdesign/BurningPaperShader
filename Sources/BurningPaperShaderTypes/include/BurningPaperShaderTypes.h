#ifndef BURNING_PAPER_SHADER_TYPES_H
#define BURNING_PAPER_SHADER_TYPES_H

#include <stdint.h>
#include <simd/simd.h>

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
    uint32_t hasIgnition;
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
    uint32_t resetState;
    uint32_t padding0;
    uint32_t padding1;
    uint32_t padding2;
} BurningPaperUniforms;

#endif /* BURNING_PAPER_SHADER_TYPES_H */
