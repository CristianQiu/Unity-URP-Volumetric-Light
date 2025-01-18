#ifndef DEPTH_AWARE_UPSAMPLE_INCLUDED
#define DEPTH_AWARE_UPSAMPLE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "./DeclareDownsampledDepthTexture.hlsl"
#include "./ProjectionUtils.hlsl"

TEXTURE2D_X(_VolumetricFogTexture);
SAMPLER(sampler_BlitTexture);

// Upsamples the volumetric fog using both the downsampled and full resolution depth information.
float4 DepthAwareUpsample(float2 uv)
{
    float2 downsampledTexelSize = _DownsampledCameraDepthTexture_TexelSize.xy;
    float2 downsampledTopLeftCornerUv = uv - (downsampledTexelSize * 0.5);
    float2 uvs[4] =
    {
        downsampledTopLeftCornerUv + float2(0.0, downsampledTexelSize.y),
        downsampledTopLeftCornerUv + downsampledTexelSize.xy,
        downsampledTopLeftCornerUv + float2(downsampledTexelSize.x, 0.0),
        downsampledTopLeftCornerUv
    };

    float4 downsampledDepths;
    
#if SHADER_TARGET >= 45
    downsampledDepths = GATHER_RED_TEXTURE2D_X(_DownsampledCameraDepthTexture, sampler_PointClamp, uv);
#else
    downsampledDepths.x = SampleDownsampledSceneDepth(uvs[0]);
    downsampledDepths.y = SampleDownsampledSceneDepth(uvs[1]);
    downsampledDepths.z = SampleDownsampledSceneDepth(uvs[2]);
    downsampledDepths.w = SampleDownsampledSceneDepth(uvs[3]);
#endif

    float fullResDepth = SampleSceneDepth(uv);
    float fullResLinearEyeDepth = LinearEyeDepthConsiderProjection(fullResDepth);
    float relativeDepthThreshold = fullResLinearEyeDepth * 0.1;
    
    float minLinearEyeDepthDist = 1e12;
    float2 nearestUv = float2(0.0, 0.0);
    int numValidDepths = 0;
    
    UNITY_UNROLL
    for (int i = 0; i < 4; ++i)
    {
        float linearEyeDepth = LinearEyeDepthConsiderProjection(downsampledDepths[i]);
        float linearEyeDepthDist = abs(fullResLinearEyeDepth - linearEyeDepth);

        bool updateNearest = linearEyeDepthDist < minLinearEyeDepthDist;
        minLinearEyeDepthDist = updateNearest ? linearEyeDepthDist : minLinearEyeDepthDist;
        nearestUv = updateNearest ? uvs[i] : nearestUv;
        
        numValidDepths += (linearEyeDepthDist < relativeDepthThreshold);
    }

    UNITY_BRANCH
    if (numValidDepths == 4)
        return SAMPLE_TEXTURE2D_X(_VolumetricFogTexture, sampler_LinearClamp, uv);
    else
        return SAMPLE_TEXTURE2D_X(_VolumetricFogTexture, sampler_PointClamp, nearestUv);
}

#endif