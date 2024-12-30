#ifndef UNITY_DECLARE_DOWNSAMPLED_DEPTH_TEXTURE_INCLUDED
#define UNITY_DECLARE_DOWNSAMPLED_DEPTH_TEXTURE_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"

TEXTURE2D_X_FLOAT(_HalfResCameraDepthTexture);
float4 _HalfResCameraDepthTexture_TexelSize;

// Samples the half resolution camera depth texture.
float SampleDownsampledSceneDepth(float2 uv)
{
    return SAMPLE_TEXTURE2D_X(_HalfResCameraDepthTexture, sampler_PointClamp, uv).r;
}

#endif