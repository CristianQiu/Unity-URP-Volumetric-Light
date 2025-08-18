#ifndef REPROJECTION_INCLUDED
#define REPROJECTION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "./DeclareDownsampledDepthTexture.hlsl"
#include "./DeclarePrevFrameDownsampledDepthTexture.hlsl"
#include "./Utils.hlsl"

#define MOTION_FULL_REJECTION 0.025
#define DEPTH_FULL_REJECTION 1.0

TEXTURE2D_X(_MotionVectorTexture);
float4 _MotionVectorTexture_TexelSize;

static const float2 Neighborhood[] = {
    float2(-1.0, -1.0), float2(0.0, -1.0), float2(1.0, -1.0),
    float2(-1.0,  0.0),                    float2(1.0,  0.0),
    float2(-1.0,  1.0), float2(0.0,  1.0), float2(1.0,  1.0)
};

// Gets the motion vector at the given uv by downsampling the motion texture following the checkerboard pattern that is used to downsample the depth texture.
float2 GetMotion(float2 uv, float2 positionCS)
{
    float4 depths = GATHER_RED_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
                
    int checkerboard = uint(positionCS.x + positionCS.y) & 1;
                
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

// Tests for motion rejection based on the magnitude of the motion vector. Values returned are in the [0, 1] range.
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

// Clamps the given history sample to the neighborhood of the current frame center texel and returns it.
float3 NeigborhoodClamp(float2 uv, float3 currentFrameSampleRGB, float3 historyRGB)
{
    float3 minSample = currentFrameSampleRGB;
    float3 maxSample = currentFrameSampleRGB;

    UNITY_UNROLL
    for (int i = 0; i < 8; ++i)
    {
        float2 neighborUv = uv + Neighborhood[i] * _BlitTexture_TexelSize.xy;
        float4 neighborSample = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, neighborUv);

        minSample = min(minSample, neighborSample);
        maxSample = max(maxSample, neighborSample);
    }

    return clamp(historyRGB, minSample, maxSample);
}

// Reprojects information from the history texture to the current frame texture using motion and depth information.
float4 Reproject(float2 uv, float2 positionCSxy, TEXTURE2D_X(_CurrentFrameTexture), TEXTURE2D_X(_HistoryTexture))
{
    float2 motion = GetMotion(uv, positionCSxy);
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
    float4 historyClamped = float4(NeigborhoodClamp(uv, currentFrame.rgb, history.rgb), history.a);

    return lerp(historyClamped, currentFrame, currentFrameWeight);
}

#endif