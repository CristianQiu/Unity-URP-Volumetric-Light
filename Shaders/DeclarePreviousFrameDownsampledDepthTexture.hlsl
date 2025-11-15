#ifndef DECLARE_PREVIOUS_FRAME_DOWNSAMPLED_DEPTH_TEXTURE_INCLUDED
#define DECLARE_PREVIOUS_FRAME_DOWNSAMPLED_DEPTH_TEXTURE_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"

TEXTURE2D_X_FLOAT(_PreviousFrameDownsampledCameraDepthTexture);
float4 _PreviousFrameDownsampledCameraDepthTexture_TexelSize;

// Samples the previous frame downsampled camera depth texture.
float SamplePreviousFrameDownsampledSceneDepth(float2 uv)
{
    return SAMPLE_TEXTURE2D_X(_PreviousFrameDownsampledCameraDepthTexture, sampler_PointClamp, uv).r;
}

#endif