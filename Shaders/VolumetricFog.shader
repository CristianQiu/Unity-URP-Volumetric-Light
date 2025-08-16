Shader "Hidden/VolumetricFog"
{
    SubShader
    {
        Tags
        { 
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "VolumetricFogRender"

            ZTest Always
            ZWrite Off
            Cull Off
            Blend Off

            HLSLPROGRAM

            #include "./VolumetricFog.hlsl"

            #pragma target 4.5

            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ PROBE_VOLUMES_L1 PROBE_VOLUMES_L2

            #pragma multi_compile_local_fragment _ _MAIN_LIGHT_CONTRIBUTION
            #pragma multi_compile_local_fragment _ _ADDITIONAL_LIGHTS_CONTRIBUTION
            #pragma multi_compile_local_fragment _ _APV_CONTRIBUTION
            #pragma multi_compile_local_fragment _ _REFLECTION_PROBES_CONTRIBUTION
            #pragma multi_compile_local_fragment _ _NOISE
            
            #pragma vertex Vert
            #pragma fragment Frag

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                return VolumetricFog(input.texcoord, input.positionCS.xy);
            }

            ENDHLSL
        }

        Pass
        {
            Name "VolumetricFogReprojection"
            
            ZTest Always
            ZWrite Off
            Cull Off
            Blend Off

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "./DeclareDownsampledDepthTexture.hlsl"
            #include "./ProjectionUtils.hlsl"
            #include "./Utils.hlsl"

            #pragma target 4.5

            #pragma vertex Vert
            #pragma fragment Frag

            TEXTURE2D_X(_VolumetricFogHistoryTexture);

            TEXTURE2D_X(_MotionVectorTexture);
            float4 _MotionVectorTexture_TexelSize;

            static const float2 Neighborhood[] = {
                float2(-1.0, -1.0), float2(0.0, -1.0), float2(1.0, -1.0),
                float2(-1.0,  0.0),                    float2(1.0,  0.0),
                float2(-1.0,  1.0), float2(0.0,  1.0), float2(1.0,  1.0)
            };

             static const float2 Square[] = {
                float2(-1.0, -1.0), float2(0.0, -1.0), float2(1.0, -1.0),
                float2(-1.0,  0.0), float2(0.0,  0.0), float2(1.0,  0.0),
                float2(-1.0,  1.0), float2(0.0,  1.0), float2(1.0,  1.0)
            };

            // Gets the motion vector at the given uv.
            float2 GetMotion(float2 uv)
            {
                return SAMPLE_TEXTURE2D_X(_MotionVectorTexture, sampler_PointClamp, uv).xy;

                // float closestDepth = 10000.0;
                // int closestNeighbor = -1;

                // for (int i = 0; i < 9; ++i)
                // {
                //     float2 uvOffset = Square[i] * _DownsampledCameraDepthTexture_TexelSize.xy;
                //     float neighborDepth = SampleDownsampledSceneDepth(uv + uvOffset);

                //     if(neighborDepth < closestDepth)
                //     {
                //         closestDepth = neighborDepth;
                //         closestNeighbor = i;
                //     }
                // }
              
                //return SAMPLE_TEXTURE2D_X(_MotionVectorTexture, sampler_PointClamp, uv + Square[closestNeighbor] * _MotionVectorTexture_TexelSize).xy;
            }

            // Clamps the given history sample to the neighborhood of the current texel and returns it.
            float3 DoNeighborhoodMinMaxClamp(float2 uv, float3 currentFrameSampleRGB, float3 historyRGB)
            {
                float3 minSample = currentFrameSampleRGB;
                float3 maxSample = currentFrameSampleRGB;

                for (int i = 0; i < 8; ++i)
                {
                    float2 neighborUv = uv + Neighborhood[i] * _BlitTexture_TexelSize.xy;
                    if (neighborUv.x <= 0.0 || neighborUv.x >= 1.0 || neighborUv.y <= 0.0 || neighborUv.y >= 1.0)
                        continue;

                    float4 neighborSample = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, neighborUv);

                    minSample = min(minSample, neighborSample);
                    maxSample = max(maxSample, neighborSample);
                }

                return clamp(historyRGB, minSample, maxSample);
            }

            // Does the history rejection test. Returns a value between 0 and 2. 0 indicates no rejection at all, 1 indicates full rejection., and 2 indicates that the history sample is not valid in any way.
            float TestForRejection(float2 uv, float2 prevUv, float2 motion)
            {
                const float MotionForFullRejection = 0.025;

                float motionLength = length(motion);

                if (prevUv.x <= 0.0 || prevUv.x >= 1.0 || prevUv.y <= 0.0 || prevUv.y >= 1.0)
                    return 2.0;

                float t = InverseLerp(motionLength, 0.0, MotionForFullRejection);

                // this immproves it a lot under extreme conditions! gets rid of hard stepped vignette when moving the cam fast through fog!
                return smoothstep(0.0, 1.0, t);

                // float depth = LinearEyeDepthConsiderProjection(SampleDownsampledSceneDepth(uv));
                // float prevDepth = LinearEyeDepthConsiderProjection(SampleDownsampledSceneDepth(prevUv));

                // const float DepthThreshold = 40000000;

                // if (abs(depth - prevDepth) >= DepthThreshold)
                //     return 1.0;

                // return 0.0;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // TODO: this is not accurate. we are using full resolution motion vectors while we render at half or quarter resolution.
                // Options: Do some kind of clever pick of the motion vectors like in depth aware upsample. Also, it should match the checkerboard min/max downsampled depth texture.
                // Inside does use velocity of closest depth fragment within 3x3 region, but I believe their resolutions do match.
                float2 uv = input.texcoord;
                float2 motion = GetMotion(uv);
                float2 prevUv = uv - motion;
                float4 currentFrame = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, uv);

                float rejection = TestForRejection(uv, prevUv, motion);
                if (rejection > 1.0)
                    return currentFrame;

                float4 history = SAMPLE_TEXTURE2D_X(_VolumetricFogHistoryTexture, sampler_PointClamp, prevUv);
                // TODO: what transmittance value should we use? should it be affected by the min/max clamping?
                float4 historyClamped = float4(DoNeighborhoodMinMaxClamp(uv, currentFrame.rgb, history.rgb), history.a);

                return lerp(historyClamped, currentFrame, 0.1);
            }

            ENDHLSL
        }

        Pass
        {
            Name "VolumetricFogHorizontalBlur"
            
            ZTest Always
            ZWrite Off
            Cull Off
            Blend Off

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "./DepthAwareGaussianBlur.hlsl"

            #pragma target 4.5

            #pragma vertex Vert
            #pragma fragment Frag

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                return DepthAwareGaussianBlur(input.texcoord, float2(1.0, 0.0), _BlitTexture, sampler_PointClamp, _BlitTexture_TexelSize.xy);
            }

            ENDHLSL
        }

        Pass
        {
            Name "VolumetricFogVerticalBlur"
            
            ZTest Always
            ZWrite Off
            Cull Off
            Blend Off

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "./DepthAwareGaussianBlur.hlsl"

            #pragma target 4.5

            #pragma vertex Vert
            #pragma fragment Frag

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                return DepthAwareGaussianBlur(input.texcoord, float2(0.0, 1.0), _BlitTexture, sampler_PointClamp, _BlitTexture_TexelSize.xy);
            }

            ENDHLSL
        }

        Pass
        {
            Name "VolumetricFogUpsampleComposition"
            
            ZTest Always
            ZWrite Off
            Cull Off
            Blend Off

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "./DepthAwareUpsample.hlsl"

            #pragma target 4.5

            #pragma vertex Vert
            #pragma fragment Frag

            TEXTURE2D_X(_VolumetricFogTexture);
            SAMPLER(sampler_BlitTexture);

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float4 volumetricFog = DepthAwareUpsample(input.texcoord, _VolumetricFogTexture);
                float4 cameraColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, input.texcoord);

                return float4(cameraColor.rgb * volumetricFog.a + volumetricFog.rgb, cameraColor.a);
            }

            ENDHLSL
        }
    }

    Fallback Off
}