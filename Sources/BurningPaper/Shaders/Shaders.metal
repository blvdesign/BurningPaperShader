#include <metal_stdlib>
#include "../../BurningPaperShaderTypes/include/BurningPaperShaderTypes.h"
using namespace metal;


struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 5; octave++) {
        value += amplitude * valueNoise(p);
        p *= 2.04;
        amplitude *= 0.5;
    }
    return value;
}

float signedFbm(float2 p) {
    return fbm(p) * 2.0 - 1.0;
}

float2 aspectCorrectedDelta(float2 delta, float2 viewSize) {
    return float2(delta.x * viewSize.x / max(viewSize.y, 1.0), delta.y);
}

float paperResistance(float2 uv, float time, float complexity, float noiseStrength) {
    float broad = fbm(uv * 5.2 + float2(12.7, 4.1));
    float cloudy = fbm(uv * 13.0 + float2(-3.3, 18.2));
    float speckle = fbm(uv * 46.0 + float2(7.0, -11.0));
    float fold = smoothstep(0.52, 0.86, fbm(uv * float2(8.0, 18.0) + float2(0.0, time * 0.004)));
    float material = broad * 0.42 + cloudy * 0.34 + speckle * 0.18 + fold * complexity * 0.16;
    return mix(0.72, 1.68, clamp(material, 0.0, 1.0)) * mix(0.86, 1.18, noiseStrength);
}

uint2 clampCoord(int2 coord, uint width, uint height) {
    return uint2(
        uint(clamp(coord.x, 0, int(width) - 1)),
        uint(clamp(coord.y, 0, int(height) - 1))
    );
}

kernel void updateBurnState(
    texture2d<float, access::read> stateIn [[texture(0)]],
    texture2d<float, access::write> stateOut [[texture(1)]],
    constant BurningPaperUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = stateOut.get_width();
    uint height = stateOut.get_height();
    if (gid.x >= width || gid.y >= height) {
        return;
    }

    if (uniforms.resetState == 1) {
        stateOut.write(float4(0.0), gid);
        return;
    }

    float2 uv = (float2(gid) + 0.5) / float2(width, height);
    int2 p = int2(gid);
    float4 state = stateIn.read(gid);
    float burn = state.r;
    float heat = state.g;
    float charAmount = state.b;
    float ashAge = state.a;

    float4 n = stateIn.read(clampCoord(p + int2(0, -1), width, height));
    float4 s = stateIn.read(clampCoord(p + int2(0, 1), width, height));
    float4 e = stateIn.read(clampCoord(p + int2(1, 0), width, height));
    float4 w = stateIn.read(clampCoord(p + int2(-1, 0), width, height));
    float4 ne = stateIn.read(clampCoord(p + int2(1, -1), width, height));
    float4 nw = stateIn.read(clampCoord(p + int2(-1, -1), width, height));
    float4 se = stateIn.read(clampCoord(p + int2(1, 1), width, height));
    float4 sw = stateIn.read(clampCoord(p + int2(-1, 1), width, height));

    float axialHeat = (n.g + s.g + e.g + w.g) * 0.25;
    float diagonalHeat = (ne.g + nw.g + se.g + sw.g) * 0.25;
    float axialBurn = (n.r + s.r + e.r + w.r) * 0.25;
    float diagonalBurn = (ne.r + nw.r + se.r + sw.r) * 0.25;
    float maxNeighborHeat = max(max(max(n.g, s.g), max(e.g, w.g)), max(max(ne.g, nw.g), max(se.g, sw.g)));
    float maxNeighborBurn = max(max(max(n.r, s.r), max(e.r, w.r)), max(max(ne.r, nw.r), max(se.r, sw.r)));
    float edgeGradient = abs(e.r - w.r) + abs(s.r - n.r) + abs(ne.r - sw.r) * 0.35 + abs(nw.r - se.r) * 0.35;

    float resistance = paperResistance(uv, uniforms.time, uniforms.frontComplexity, uniforms.noiseStrength);
    float crawl = fbm(uv * 18.0 + float2(uniforms.time * 0.017, -uniforms.time * 0.012));
    float emberPockets = smoothstep(0.56, 0.9, fbm(uv * 53.0 + float2(8.0, -2.0)));
    float spreadGain = uniforms.spreadRate * uniforms.deltaTime * mix(0.44, 1.58, crawl);

    if (uniforms.hasIgnition == 1) {
        float2 delta = aspectCorrectedDelta(uv - uniforms.ignitionPoint, uniforms.viewSize);
        float ignitionDistance = length(delta);
        float angle = atan2(delta.y, delta.x);
        float lobeCount = floor(mix(3.0, 9.0, hash21(float2(uniforms.ignitionSeed, 2.7))));
        float radialLobes = sin(angle * lobeCount + uniforms.ignitionSeed * 1.37) * 0.5 + 0.5;
        float localWarp = signedFbm(uv * (21.0 + lobeCount) + uniforms.ignitionSeed);
        float variance = uniforms.ignitionVariance;
        float roughDistance = ignitionDistance * (1.0 + (localWarp * 0.52 + (radialLobes - 0.5) * 0.38) * variance);
        float roughRadius = uniforms.ignitionRadius * uniforms.ignitionRadiusScale * mix(0.9, 1.18, uniforms.flameAmount);
        float ignition = smoothstep(roughRadius, roughRadius * 0.12, roughDistance);
        float grain = fbm(uv * 74.0 + float2(uniforms.ignitionSeed * 0.17, -uniforms.ignitionSeed * 0.11));
        float fiberGate = smoothstep(0.20, 0.86, grain + radialLobes * 0.14 + localWarp * 0.18);
        float emberHot = smoothstep(0.55, 0.96, grain + hash21(floor(uv * 38.0) + uniforms.ignitionSeed) * 0.28);
        float ignitionCore = ignition * mix(0.52, 1.12, fiberGate);
        heat = max(heat, ignitionCore * uniforms.ignitionHeatScale * mix(0.86, 1.22, emberHot));
        burn = max(burn, ignitionCore * mix(0.016, 0.047, uniforms.flameAmount));
        charAmount = max(charAmount, ignition * (0.04 + emberHot * 0.09));
    }

    if (burn < 0.992) {
        float neighborHeat = axialHeat * 0.56 + diagonalHeat * 0.28 + maxNeighborHeat * 0.16;
        float neighborBurn = axialBurn * 0.58 + diagonalBurn * 0.27 + maxNeighborBurn * 0.15;
        float frontPull = smoothstep(0.14, 0.86, neighborBurn);
        float raggedSignal = clamp(edgeGradient * 0.78 + emberPockets * 0.32 + crawl * 0.18, 0.0, 1.0);
        float raggedBoost = mix(0.66, 1.46, raggedSignal);
        heat += (neighborHeat * 0.72 + frontPull * 0.48) * spreadGain * raggedBoost / resistance;

        float resistance01 = clamp((resistance - 0.72) / 0.96, 0.0, 1.0);
        float ignitionThreshold = mix(0.24, 0.56, resistance01);
        float burnEnergy = max(heat - ignitionThreshold, 0.0);
        burn += burnEnergy * uniforms.burnSpeed * uniforms.deltaTime * mix(0.74, 1.35, emberPockets) / resistance;
    }

    float charTarget = smoothstep(0.18, 0.86, burn) * (0.36 + heat * 0.5 + emberPockets * 0.22);
    charAmount = max(charAmount, charTarget);
    charAmount = clamp(charAmount - max(ashAge - 0.55, 0.0) * uniforms.deltaTime * 0.12, 0.0, 1.0);

    float coolingNoise = mix(0.76, 1.38, fbm(uv * 31.0 + float2(uniforms.time * 0.034, -uniforms.time * 0.021)));
    float cooling = uniforms.coolingRate * uniforms.deltaTime * (0.34 + burn * 1.08 + ashAge * 0.3) * coolingNoise;
    heat = clamp(heat - cooling, 0.0, 1.0);
    burn = clamp(burn, 0.0, 1.0);

    float cooledChar = (1.0 - smoothstep(0.12, 0.74, heat));
    float ashGrowth = smoothstep(0.44, 0.96, burn) * cooledChar * (0.2 + charAmount * 0.78);
    ashAge = clamp(ashAge + ashGrowth * uniforms.deltaTime * 0.72, 0.0, 1.0);

    stateOut.write(float4(burn, heat, charAmount, ashAge), gid);
}

vertex VertexOut fullscreenVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

fragment half4 paperFragment(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> stateTexture [[texture(0)]],
    constant BurningPaperUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler linearSampler(address::clamp_to_edge, filter::linear);

    float2 uv = in.uv;
    float4 state = stateTexture.sample(linearSampler, uv);
    float burn = state.r;
    float heat = state.g;
    float charAmount = state.b;
    float ashAge = state.a;
    float2 texel = 1.0 / uniforms.textureSize;

    float4 sxp = stateTexture.sample(linearSampler, uv + float2(texel.x * 2.0, 0.0));
    float4 sxn = stateTexture.sample(linearSampler, uv - float2(texel.x * 2.0, 0.0));
    float4 syp = stateTexture.sample(linearSampler, uv + float2(0.0, texel.y * 2.0));
    float4 syn = stateTexture.sample(linearSampler, uv - float2(0.0, texel.y * 2.0));
    float nearbyBurn = max(max(max(burn, sxp.r), max(sxn.r, syp.r)), syn.r);
    nearbyBurn = max(nearbyBurn, stateTexture.sample(linearSampler, uv + texel * 4.0).r);
    nearbyBurn = max(nearbyBurn, stateTexture.sample(linearSampler, uv - texel * 4.0).r);
    float edgeGradient = length(float2(sxp.r - sxn.r, syp.r - syn.r));

    float paperClouds = fbm(uv * 9.0 + float2(4.0, 1.2));
    float paperMottle = fbm(uv * 34.0 + float2(-8.0, 13.0));
    float paperSpeckle = fbm(uv * 115.0) * 0.018;
    float softFoldA = signedFbm(uv * float2(6.5, 15.0) + float2(1.0, 4.0));
    float softFoldB = signedFbm(uv * float2(22.0, 8.0) + float2(-5.0, 9.0));
    float foldLine = smoothstep(0.72, 0.94, abs(softFoldA)) * 0.045;
    float wrinkleShade = (softFoldA * 0.018 + softFoldB * 0.014 - foldLine) * uniforms.paperWrinkleAmount;
    float3 paper = uniforms.paperColor.rgb;
    paper += (paperClouds - 0.5) * 0.035 + (paperMottle - 0.5) * 0.028 + paperSpeckle + wrinkleShade;

    float edgeBreakup = signedFbm(uv * 56.0 + signedFbm(uv * 10.0) * 3.4);
    float fineBreakup = signedFbm(uv * float2(150.0, 84.0));
    float edgeCut = clamp(0.70 + edgeBreakup * 0.13 * uniforms.frontComplexity + fineBreakup * 0.032, 0.52, 0.86);
    float paperAlpha = 1.0 - smoothstep(edgeCut - 0.026, edgeCut + 0.076, burn);

    float edgeMask = smoothstep(0.018, 0.12, edgeGradient) * (1.0 - smoothstep(edgeCut + 0.14, edgeCut + 0.36, burn));
    edgeMask *= smoothstep(edgeCut - 0.24, edgeCut + 0.06, nearbyBurn + heat * 0.22);
    float edgeSegmentNoise = fbm(uv * float2(44.0, 92.0) + float2(uniforms.time * 0.58, -uniforms.time * 0.34));
    float emberSegmentNoise = fbm(uv * 118.0 + float2(-uniforms.time * 0.9, uniforms.time * 0.24));
    float freshEdge = smoothstep(0.04, 0.48, heat + edgeGradient * 1.25) * (1.0 - smoothstep(0.42, 0.96, ashAge));
    float segmentedFront = smoothstep(0.48, 0.86, edgeSegmentNoise + heat * 0.34 + edgeGradient * 0.8);
    float activeFront = edgeMask * freshEdge * mix(0.18, 1.0, segmentedFront);

    float stain = smoothstep(edgeCut - uniforms.stainWidth, edgeCut - uniforms.charWidth * 1.5, burn) * paperAlpha;
    float dryBrown = smoothstep(edgeCut - uniforms.stainWidth * 1.25, edgeCut - uniforms.stainWidth * 0.16, nearbyBurn) * paperAlpha;

    float charNoise = fbm(uv * 72.0 + float2(3.2, -6.8));
    float brittlePatches = smoothstep(0.54, 0.9, charNoise + ashAge * 0.08) * charAmount;
    float charLip = smoothstep(edgeCut - uniforms.charWidth * 4.6, edgeCut + uniforms.charWidth * 0.76, nearbyBurn) * edgeMask;
    float sootRim = charLip * (0.36 + charAmount * 0.64 + brittlePatches * 0.28);
    sootRim *= mix(0.82, 1.18, fbm(uv * 96.0 + float2(4.1, -9.3)));

    float ashNoiseA = fbm(uv * 88.0 + float2(-11.0, 7.0));
    float ashNoiseB = fbm(uv * 185.0 + float2(2.0, uniforms.time * 0.02));
    float powder = smoothstep(0.62, 0.92, ashNoiseA) * smoothstep(0.42, 1.0, ashAge);
    float ashFlecks = smoothstep(0.78, 0.985, ashNoiseB) * ashAge * charAmount;
    float interiorAsh = (powder * 0.12 + ashFlecks * 0.13) * smoothstep(edgeCut + 0.04, edgeCut + 0.32, burn);

    float hotNoise = fbm(uv * float2(40.0, 78.0) + float2(uniforms.time * 1.22, -uniforms.time * 2.55));
    float flicker = 0.72 + 0.28 * sin(uniforms.time * 18.0 + hash21(floor(uv * 72.0)) * 6.2831);
    float hotSegments = smoothstep(0.64, 0.92, hotNoise + heat * 0.18 + emberSegmentNoise * 0.12) * activeFront * uniforms.flameAmount * flicker;
    float flameCore = smoothstep(0.88, 1.08, hotNoise + heat * 0.36 + emberSegmentNoise * 0.16) * activeFront * uniforms.flameAmount;
    float emberDots = smoothstep(0.82, 0.985, fbm(uv * 132.0 + float2(uniforms.time * 0.46, -uniforms.time * 1.35))) * activeFront * uniforms.emberAmount;

    float smokeNoise = fbm(uv * float2(19.0, 38.0) + float2(0.0, -uniforms.time * 0.16));
    float smoke = smoothstep(0.5, 0.88, smokeNoise) * activeFront * uniforms.smokeAmount * smoothstep(0.25, 1.0, ashAge + charAmount);

    float paperLift = edgeMask * paperAlpha * (0.18 + edgeGradient * 1.8);
    float3 stained = mix(paper, float3(0.76, 0.57, 0.35), dryBrown * 0.38);
    stained += paperLift * float3(0.035, 0.026, 0.014);
    stained = mix(stained, float3(0.56, 0.30, 0.16), stain * 0.5);
    float3 charred = mix(stained, float3(0.18, 0.105, 0.065), sootRim * 0.74);
    charred = mix(charred, float3(0.05, 0.042, 0.034), charLip * (0.38 + ashAge * 0.16));
    charred = mix(charred, float3(0.53, 0.515, 0.48), interiorAsh);

    float3 heatColor = float3(1.0, 0.18, 0.055) * hotSegments * 0.58;
    float3 flameColor = float3(1.0, 0.48, 0.08) * hotSegments * 0.86 + float3(1.0, 0.92, 0.36) * flameCore;
    float3 emberColor = float3(1.0, 0.36, 0.08) * (emberDots * 0.58 + heat * activeFront * uniforms.glowAmount * 0.14);
    float3 color = charred + heatColor + flameColor + emberColor;
    color = mix(color, float3(0.24, 0.235, 0.22), smoke * 0.34);

    float alpha = paperAlpha;
    alpha = max(alpha, sootRim * 0.46 + stain * 0.16);
    alpha = max(alpha, interiorAsh * 0.1 + ashFlecks * 0.08);
    alpha = max(alpha, smoke * 0.11 + hotSegments * 0.18 + flameCore * 0.34 + emberDots * 0.08);
    alpha = clamp(alpha, 0.0, 1.0);

    return half4(half3(color), half(alpha));
}
