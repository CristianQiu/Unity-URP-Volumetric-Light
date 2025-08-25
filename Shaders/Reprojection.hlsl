#ifndef REPROJECTION_INCLUDED
#define REPROJECTION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "./DeclareDownsampledDepthTexture.hlsl"
#include "./DeclarePrevFrameDownsampledDepthTexture.hlsl"
#include "./Utils.hlsl"

#define MOTION_FULL_REJECTION 0.025
#define DEPTH_FULL_REJECTION 1.0
#define USE_CLIPPING 1

TEXTURE2D_X(_MotionVectorTexture);
float4 _MotionVectorTexture_TexelSize;

static const float2 Neighborhood[] = {
    float2(-1.0, -1.0), float2(0.0, -1.0), float2(1.0, -1.0),
    float2(-1.0,  0.0),                    float2(1.0,  0.0),
    float2(-1.0,  1.0), float2(0.0,  1.0), float2(1.0,  1.0)
};

// Samples motion vectors for the given UV coordinates. Since we are using the motion to work with the downsampled depth texture, we need to sample the motion vectors following the same checkerboard pattern as the depth texture.
float2 GetMotion(float2 uv)
{
    float4 depths = GATHER_RED_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
                
    // TODO: equivalent to positionCS * 2 at half resolution. This is more expensive but we would need to pass in the downsample factor.
    uint2 positionCSxy = uint2(round(uv * _CameraDepthTexture_TexelSize.zw));
    int checkerboard = uint(positionCSxy.x + positionCSxy.y) & 1;
                
    int depthUv = 0;
    float depth = depths.x;

    if (checkerboard > 0)
    {
        if (depths.y < depth)
        {
            depthUv  = 1;
            depth = depths.y;
        }
                    
        if (depths.z < depth)
        {
            depthUv  = 2;
            depth = depths.z;
        }

        if (depths.w < depth)
        {
            depthUv  = 3;
            depth = depths.w;
        }
    }
    else
    {
        if (depths.y > depth)
        {
            depthUv  = 1;
            depth = depths.y;
        }
                    
        if (depths.z > depth)
        {
            depthUv  = 2;
            depth = depths.z;
        }

        if (depths.w > depth)
        {
            depthUv  = 3;
            depth = depths.w;
        }
    }

    float2 downsampledTexelSize = _DownsampledCameraDepthTexture_TexelSize.xy;
    float2 downsampledTopLeftCornerUv = uv - (downsampledTexelSize * 0.5);

    float2 uvs[4] =
    {
        downsampledTopLeftCornerUv + float2(0.0, downsampledTexelSize.y),
        downsampledTopLeftCornerUv + downsampledTexelSize.xy,
        downsampledTopLeftCornerUv + float2(downsampledTexelSize.x, 0.0),
        downsampledTopLeftCornerUv
    };

    return SAMPLE_TEXTURE2D_X(_MotionVectorTexture, sampler_PointClamp, uvs[depthUv]).xy;
}

// Tests for motion rejection based on the motion vector. Values returned are in the [0, 1] range.
float TestForMotionRejection(float2 motion)
{
    float motionLength = length(motion);
    float rejection = InverseLerp(0.0, MOTION_FULL_REJECTION, motionLength);
                
    return smoothstep(0.0, 1.0, rejection);
}

// Tests for depth rejection based on the difference between the current and previous frame depths. Values returned are in the [0, 1] range.
float TestForDepthRejection(float2 uv, float2 prevUv)
{
    float currDepth = LinearEyeDepthConsiderProjection(SampleDownsampledSceneDepth(uv));
    float prevDepth = LinearEyeDepthConsiderProjection(SamplePrevFrameDownsampledSceneDepth(prevUv));

    float depthDiff = abs(prevDepth - currDepth);
    float rejection = InverseLerp(0.0, DEPTH_FULL_REJECTION, depthDiff);

    return smoothstep(0.0, 1.0, rejection);
}

// From Playdead's INSIDE: https://github.com/playdeadgames/temporal/blob/master/Assets/Shaders/TemporalReprojection.shader
float4 ClipAABB(float3 aabb_min, float3 aabb_max, float4 p, float4 q)
{
    float3 p_clip = 0.5 * (aabb_max + aabb_min);
    float3 e_clip = 0.5 * (aabb_max - aabb_min) + FLOAT_EPSILON;

    float4 v_clip = q - float4(p_clip, p.w);
    float3 v_unit = v_clip.xyz / e_clip;
    float3 a_unit = abs(v_unit);
    float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

    if (ma_unit > 1.0)
        return float4(p_clip, p.w) + v_clip / ma_unit;
    else
        return q;
}

// Clamps the given history sample to the neighborhood of the current frame center texel and returns it.
float4 NeigborhoodClamp(float2 uv, float4 currentFrameSample, float4 history)
{
    float4 minSample = currentFrameSample;
    float4 maxSample = currentFrameSample;

#if USE_CLIPPING
    float4 avg = currentFrameSample;
#endif

    UNITY_UNROLL
    for (int i = 0; i < 8; ++i)
    {
        float2 neighborUv = uv + Neighborhood[i] * _BlitTexture_TexelSize.xy;
        float4 neighborSample = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, neighborUv);

        minSample = min(minSample, neighborSample);
        maxSample = max(maxSample, neighborSample);

#if USE_CLIPPING
        avg += neighborSample;
#endif
    }

#if USE_CLIPPING
    return ClipAABB(minSample.xyz, maxSample.xyz, clamp(avg / 9.0, minSample, maxSample), history);
#else
    return clamp(history, minSample, maxSample);
#endif
}

// Reprojects information from the history texture to the current frame texture using motion and depth information.
float4 Reproject(float2 uv, TEXTURE2D_X(_CurrentFrameTexture), TEXTURE2D_X(_HistoryTexture))
{
    float2 motion = GetMotion(uv);
    float2 prevUv = uv - motion;
                
    float4 currentFrame = SAMPLE_TEXTURE2D_X(_CurrentFrameTexture, sampler_PointClamp, uv);

    if (prevUv.x <= 0.0 || prevUv.x >= 1.0 || prevUv.y <= 0.0 || prevUv.y >= 1.0)
        return currentFrame;

    float rejectionMotion = TestForMotionRejection(motion);
    float rejectionDepth = TestForDepthRejection(uv, prevUv);

    float rejection = rejectionMotion + rejectionDepth;
    float currentFrameWeight = clamp(rejection, 0.1, 1.0);
                
    if (currentFrameWeight >= 1.0)
        return currentFrame;
                
    float4 history = SAMPLE_TEXTURE2D_X(_HistoryTexture, sampler_PointClamp, prevUv);
    history = NeigborhoodClamp(uv, currentFrame, history);

    return lerp(history, currentFrame, currentFrameWeight);
}

#endif