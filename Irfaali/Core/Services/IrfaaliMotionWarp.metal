#include <metal_stdlib>
using namespace metal;

kernel void irfaaliMotionWarpInterpolate(
    texture2d<float, access::sample> source [[texture(0)]],
    texture2d<float, access::sample> target [[texture(1)]],
    texture2d<float, access::read> forwardFlow [[texture(2)]],
    texture2d<float, access::read> backwardFlow [[texture(3)]],
    texture2d<float, access::write> output [[texture(4)]],
    constant float &fraction [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    constexpr sampler linearSampler(
        coord::normalized,
        address::clamp_to_edge,
        filter::linear
    );

    const float2 dimensions = float2(output.get_width(), output.get_height());
    const float2 inverseDimensions = 1.0 / dimensions;
    const float2 uv = (float2(gid) + 0.5) * inverseDimensions;

    // Vision optical-flow vectors represent per-pixel motion. Approximate the
    // inverse mapping for the intermediate instant from both temporal directions.
    const float2 forward = forwardFlow.read(gid).xy;
    const float2 backward = backwardFlow.read(gid).xy;

    const float2 sourceUV = clamp(
        uv - forward * fraction * inverseDimensions,
        float2(0.0),
        float2(1.0)
    );
    const float2 targetUV = clamp(
        uv - backward * (1.0 - fraction) * inverseDimensions,
        float2(0.0),
        float2(1.0)
    );

    const float4 warpedSource = source.sample(linearSampler, sourceUV);
    const float4 warpedTarget = target.sample(linearSampler, targetUV);
    const float4 motionCompensated = mix(warpedSource, warpedTarget, fraction);

    // Confidence is intentionally conservative around occlusions. Forward and
    // backward flow should roughly cancel for the same moving point. Normalize
    // that disagreement by motion magnitude so fast but valid motion does not get
    // punished merely for being fast.
    const float forwardMagnitude = length(forward);
    const float backwardMagnitude = length(backward);
    const float motionMagnitude = max(forwardMagnitude, backwardMagnitude);
    const float normalizedFlowDisagreement = length(forward + backward) /
        max(forwardMagnitude + backwardMagnitude, 1.0);
    const float flowConfidence = 1.0 - smoothstep(0.12, 0.62, normalizedFlowDisagreement);

    // Large photometric disagreement after warping usually means an occlusion,
    // a bad flow vector or a newly revealed region. Those pixels are exactly where
    // a 50/50 blend produces the most visible double-edge ghosting.
    const float photometricError = length(warpedSource.rgb - warpedTarget.rgb);
    const float photoConfidence = 1.0 - smoothstep(0.08, 0.42, photometricError);

    // Static areas are already stable even when tiny flow noise disagrees. Apply
    // the strict confidence gate progressively as real motion grows.
    const float movingWeight = smoothstep(0.35, 2.0, motionMagnitude);
    const float strictConfidence = clamp(flowConfidence * photoConfidence, 0.0, 1.0);
    const float motionConfidence = mix(1.0, strictConfidence, movingWeight);

    // For genuinely uncertain pixels, choose the temporally nearer original sample
    // instead of creating a transparent-looking double edge. This fallback is only
    // per-pixel; the frame remains motion synthesized everywhere confidence is good.
    const float4 originalSource = source.sample(linearSampler, uv);
    const float4 originalTarget = target.sample(linearSampler, uv);
    const float4 occlusionFallback = fraction < 0.5 ? originalSource : originalTarget;

    float4 result = mix(occlusionFallback, motionCompensated, motionConfidence);
    result.a = 1.0;
    output.write(result, gid);
}
