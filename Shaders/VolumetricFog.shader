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
            #include "./DeclarePrevFrameDownsampledDepthTexture.hlsl"
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

                int closestNeighbor = 0;
                float closestDepth = SampleDownsampledSceneDepth(uv + (Square[0] * _DownsampledCameraDepthTexture_TexelSize.xy));

                UNITY_UNROLL
                for (int i = 1; i < 9; ++i)
                {
                    float2 currUv = uv + Square[i] * _DownsampledCameraDepthTexture_TexelSize.xy;
                    float currDepth = SampleDownsampledSceneDepth(currUv);

                    if (currDepth < closestDepth)
                    {
                        closestDepth = currDepth;
                        closestNeighbor = i;
                    }
                }
              
                return SAMPLE_TEXTURE2D_X(_MotionVectorTexture, sampler_PointClamp, uv + Square[closestNeighbor] * _MotionVectorTexture_TexelSize).xy;
            }

            float TestForDepthRejection(float2 uv, float2 prevUv)
            {
                const float DepthDiffForFullRejection = 1.0;

                float currDepth = LinearEyeDepthConsiderProjection(SampleDownsampledSceneDepth(uv));
                float prevDepth = LinearEyeDepthConsiderProjection(SamplePrevFrameDownsampledSceneDepth(prevUv));

                float depthDiff = abs(prevDepth - currDepth);
                float rejection = InverseLerp(0.0, DepthDiffForFullRejection, depthDiff);

                return smoothstep(0.0, 1.0, rejection);
            }

            float TestForMotionRejection(float2 motion)
            {
                const float MotionForFullRejection = 0.025;

                float motionLength = length(motion);
                float rejection = InverseLerp(0.0, MotionForFullRejection, motionLength);
                
                return smoothstep(0.0, 1.0, rejection);
            }

            // Clamps the given history sample to the neighborhood of the current frame center texel and returns it.
            float3 DoNeighborhoodMinMaxClamp(float2 uv, float3 currentFrameSampleRGB, float3 historyRGB)
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

                 if (prevUv.x <= 0.0 || prevUv.x >= 1.0 || prevUv.y <= 0.0 || prevUv.y >= 1.0)
                    return currentFrame;

                float rejectionDepth = TestForDepthRejection(uv, prevUv);
                float rejectionMotion = TestForMotionRejection(motion);

                float rejection = rejectionDepth + rejectionMotion;
                float currentFrameWeight = clamp(rejection, 0.1, 1.0);
                
                if (currentFrameWeight >= 1.0)
                    return currentFrame;
                
                float4 history = SAMPLE_TEXTURE2D_X(_VolumetricFogHistoryTexture, sampler_PointClamp, prevUv);
                float4 historyClamped = float4(DoNeighborhoodMinMaxClamp(uv, currentFrame.rgb, history.rgb), history.a);

                return lerp(historyClamped, currentFrame, currentFrameWeight);
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