#ifndef DECLARE_PREV_FRAME_DOWNSAMPLED_DEPTH_TEXTURE_INCLUDED
#define DECLARE_PREV_FRAME_DOWNSAMPLED_DEPTH_TEXTURE_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"

TEXTURE2D_X_FLOAT(_PrevFrameDownsampledCameraDepthTexture);
float4 _PrevFrameDownsampledCameraDepthTexture_TexelSize;

// Samples the previous frame downsampled camera depth texture.
float SamplePrevFrameDownsampledSceneDepth(float2 uv)
{
    return SAMPLE_TEXTURE2D_X(_PrevFrameDownsampledCameraDepthTexture, sampler_PointClamp, uv).r;
}

#endif