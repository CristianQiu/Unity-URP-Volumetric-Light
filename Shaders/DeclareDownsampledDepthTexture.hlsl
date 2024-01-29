TEXTURE2D_X_FLOAT(_HalfResCameraDepthTexture);
float4 _HalfResCameraDepthTexture_TexelSize;

// Samples the half resolution camera depth texture and returns the depth considering UNITY_REVERSED_Z.
float SampleDownsampledSceneDepthConsiderReversedZ(float2 uv)
{
	float depth = SAMPLE_TEXTURE2D_X(_HalfResCameraDepthTexture, sampler_PointClamp, UnityStereoTransformScreenSpaceTex(uv)).r;

#if !UNITY_REVERSED_Z
	depth = lerp(UNITY_NEAR_CLIP_VALUE, 1.0, depth);
#endif

	return depth;
}