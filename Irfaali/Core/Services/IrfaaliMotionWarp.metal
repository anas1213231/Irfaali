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

    // A forward/backward consistency check reduces obvious tearing around
    // occlusions. When the motion fields strongly disagree, fall back smoothly
    // toward a conventional temporal blend instead of trusting a bad warp.
    const float inconsistency = length(forward + backward);
    const float motionConfidence = 1.0 / (1.0 + 0.08 * inconsistency);
    const float4 temporalBlend = mix(
        source.sample(linearSampler, uv),
        target.sample(linearSampler, uv),
        fraction
    );

    float4 result = mix(temporalBlend, motionCompensated, clamp(motionConfidence, 0.0, 1.0));
    result.a = 1.0;
    output.write(result, gid);
}
