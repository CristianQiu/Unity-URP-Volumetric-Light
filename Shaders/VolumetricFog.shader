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
            Name "VolumetricFog"

            ZTest Always
            ZWrite Off
            Cull Off
            Blend Off

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/VolumeRendering.hlsl"
            #include "./DeclareDownsampledDepthTexture.hlsl"

            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ _MAIN_LIGHT_CONTRIBUTION_DISABLED
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS_CONTRIBUTION_DISABLED

            #pragma vertex Vert
            #pragma fragment Frag

            int _FrameCount;
            uint _CustomAdditionalLightsCount;
            float _Distance;
            float _BaseHeight;
            float _MaximumHeight;
            float _GroundHeight;
            float _Density;
            float _Absortion;
            float _MainLightAnisotropy;
            float _MainLightScattering;
            float3 _MainLightColorTint;
            float _AdditionalLightsAnisotropy;
            float _AdditionalLightsScattering;
            float _AdditionalLightsRadiusSq;
            int _MaxSteps;

            // Gets the fog density at the given world height.
            float GetFogDensity(float posWSy)
            {
                float t = saturate((posWSy - _BaseHeight) / (_MaximumHeight - _BaseHeight));
                t = 1.0 - t;
                t = lerp(t, 0.0, posWSy < _GroundHeight);

                return _Density * t;
            }

            // Gets the main light color at one raymarch step.
            float3 GetStepMainLightColor(float3 currPosWS, float phaseMainLight, float density)
            {
#if _MAIN_LIGHT_CONTRIBUTION_DISABLED
                return float3(0.0, 0.0, 0.0);
#endif
                // get the main light with shadow attenuation already set
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(currPosWS));
#if _LIGHT_COOKIES
                // when light cookies are enabled and one is set for the main light, also factor it
                mainLight.color *= SampleMainLightCookie(currPosWS);
#endif
                // return the final color
                return (mainLight.color * _MainLightColorTint) * (mainLight.shadowAttenuation * phaseMainLight * density * _MainLightScattering);
            }

            // Gets the accumulated color from additional lights at one raymarch step.
            float3 GetStepAdditionalLightsColor(float2 texcoord, float3 currPosWS, float3 rd, float density)
            {
#if _ADDITIONAL_LIGHTS_CONTRIBUTION_DISABLED
                return float3(0.0, 0.0, 0.0);
#endif
#if _FORWARD_PLUS
                // Forward+ rendering path needs this data before the light loop
                InputData inputData = (InputData)0;
                inputData.normalizedScreenSpaceUV = texcoord;
                inputData.positionWS = currPosWS;
#endif
                // initialize the accumulated color from additional lights
                float3 additionalLightsColor = float3(0.0, 0.0, 0.0);   

                // loop differently throught lights in Forward+ while considering Forward and Deferred too
                LIGHT_LOOP_BEGIN(_CustomAdditionalLightsCount)
                    Light additionalLight = GetAdditionalPerObjectLight(lightIndex, currPosWS);
                    additionalLight.shadowAttenuation = AdditionalLightRealtimeShadow(lightIndex, currPosWS, additionalLight.direction);
#if _LIGHT_COOKIES
                    // when light cookies are enabled and a cookie is set for this additional light also factor it
                    additionalLight.color *= SampleAdditionalLightCookie(lightIndex, currPosWS);
#endif
                    // calculate the phase function for this additional light
                    float phaseAdditionalLight = CornetteShanksPhaseFunction(_AdditionalLightsAnisotropy, dot(rd, additionalLight.direction));

                    // See unity.render-pipelines.universal\ShaderLibrary\RealtimeLights.hlsl - GetAdditionalPerObjectLight
#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
                    float4 additionalLightPos = _AdditionalLightsBuffer[lightIndex].position;
#else
                    float4 additionalLightPos = _AdditionalLightsPosition[lightIndex];
#endif
                    // TODO: This is only useful for spot lights. Additional lights can include directional lights and point lights too.
                    // gradually reduce additional lights scattering to zero at their origin to try to avoid flicker-aliasing mainly due to bright spotlights
                    float3 distToPos = additionalLightPos.xyz - currPosWS;
                    float distToPosMagnitudeSq = dot(distToPos, distToPos);
                    float newScattering = smoothstep(0.0, _AdditionalLightsRadiusSq, distToPosMagnitudeSq) * _AdditionalLightsScattering;

                    // accumulate the total color for additional lights
                    additionalLightsColor += (additionalLight.color * (additionalLight.shadowAttenuation * additionalLight.distanceAttenuation * phaseAdditionalLight * density * newScattering));
                LIGHT_LOOP_END

                return additionalLightsColor;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // prepare the ray origin and direction
                float depth = SampleDownsampledSceneDepthConsiderReversedZ(input.texcoord);
                float3 posWS = ComputeWorldSpacePosition(input.texcoord, depth, UNITY_MATRIX_I_VP);
                float3 ro = GetCameraPositionWS();
                float3 offset = posWS - ro;
                float offsetLength = length(offset);
                float3 rd = offset / offsetLength;

                // calculate the step length and jitter
                float stepLength = _Distance / (float)_MaxSteps;
                float jitter = stepLength * InterleavedGradientNoise(input.positionCS.xy, _FrameCount);

                // calculate the phase function for the main light and part of the extinction factor
                float phaseMainLight = CornetteShanksPhaseFunction(_MainLightAnisotropy, dot(rd, GetMainLight().direction));
                float minusStepLengthTimesAbsortion = -stepLength * _Absortion;
                
                // initialize the volumetric fog color and transmittance
                float3 volumetricFogColor = float3(0.0, 0.0, 0.0);
                float transmittance = 1.0;

                UNITY_LOOP
                for (int i = 0; i < _MaxSteps; ++i)
                {
                    // calculate the distance we are at
                    float dist = jitter + i * stepLength;

                    // perform depth test to break out early
                    UNITY_BRANCH
                    if (dist >= offsetLength)
                        break;

                    // calculate the current world position
                    float3 currPosWS = ro + rd * dist;

                    // calculate density and continue if it is not meaningful
                    float density = GetFogDensity(currPosWS.y);
                    if (density <= 0.0)
                        continue;

                    // calculate attenuation
                    float stepAttenuation = exp(minusStepLengthTimesAbsortion * density);
                    
                    // attenuate transmittance
                    transmittance *= stepAttenuation;

                    // calculate the colors at this step and accumulate them
                    float3 mainLightColor = GetStepMainLightColor(currPosWS, phaseMainLight, density);
                    float3 additionalLightsColor = GetStepAdditionalLightsColor(input.texcoord, currPosWS, rd, density);

                    // TODO: add ambient?
                    float3 stepColor = mainLightColor + additionalLightsColor;
                    volumetricFogColor += (stepColor * (transmittance * stepLength));
                }

                return float4(volumetricFogColor, transmittance);
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

            #pragma vertex Vert
            #pragma fragment Frag

#if UNITY_VERSION < 202320
            float4 _BlitTexture_TexelSize;
#endif

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                return DepthAwareGaussianBlur(input.texcoord, float2(1.0, 0.0), _BlitTexture, sampler_LinearClamp, _BlitTexture_TexelSize.xy);
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

            #pragma vertex Vert
            #pragma fragment Frag

#if UNITY_VERSION < 202320
            float4 _BlitTexture_TexelSize;
#endif

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                return DepthAwareGaussianBlur(input.texcoord, float2(0.0, 1.0), _BlitTexture, sampler_LinearClamp, _BlitTexture_TexelSize.xy);
            }

            ENDHLSL
        }

        Pass
        {
            Name "VolumetricFogComposition"
            
            ZTest Always
            ZWrite Off
            Cull Off
            Blend Off

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "./DeclareDownsampledDepthTexture.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            TEXTURE2D_X(_VolumetricFogTexture);
            SAMPLER(sampler_BlitTexture);

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // get the full resolution depth and convert it to linear eye depth
                float fullResDepth = LoadSceneDepth(input.positionCS.xy);
                float linearFullResDepth = LinearEyeDepth(fullResDepth, _ZBufferParams);

                // get the texel size from the downsampled depth texture
                float2 texelSize = _HalfResCameraDepthTexture_TexelSize.xy;

                // calculate the UVs to sample the downsampled depths
                float2 topLeftUv = input.texcoord - (texelSize * 0.5);
                float2 uvs[4] = 
                {
                    topLeftUv + float2(0.0, texelSize.y),
                    topLeftUv + texelSize.xy,
                    topLeftUv + float2(texelSize.x, 0.0),
                    topLeftUv,
                };

                // initialize variables to validate the depths
                int numValidDepths = 0;
                float relativeDepthThreshold = linearFullResDepth * 0.1;

                // initialize the minimum depth distance towards the full resolution depth
                float minDepthDist = 1e12;
                float2 nearestUv;

                UNITY_UNROLL
                for (int i = 0; i < 4; ++i)
                {
                    // sample the lower resolution depth and convert to linear eye depth
                    float2 uv = uvs[i];
                    float depth = SampleDownsampledSceneDepthConsiderReversedZ(uv);
                    float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);

                    // check the depth distance
                    float depthDist = abs(linearFullResDepth - linearEyeDepth);

                    // update the minimum when necessary
                    UNITY_FLATTEN
                    if (depthDist < minDepthDist)
                    {
                        minDepthDist = depthDist;
                        nearestUv = uvs[i];
                    }

                    // count the number of valid depths according to the threshold, as we will act differently if all of them are valid or not
                    numValidDepths += (depthDist < relativeDepthThreshold); 
                }

                float4 volumetricFog;

                // use bilinear sampling if depths are similar, and point sampling otherwise
                UNITY_BRANCH
                if (numValidDepths == 4)
                    volumetricFog = SAMPLE_TEXTURE2D_X(_VolumetricFogTexture, sampler_LinearClamp, input.texcoord);
                else
                    volumetricFog = SAMPLE_TEXTURE2D_X(_VolumetricFogTexture, sampler_PointClamp, nearestUv);

                float4 cameraColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, input.texcoord);

                // attenuate the camera color with the fog and add the fog on top
                return float4(cameraColor.rgb * volumetricFog.a + volumetricFog.rgb, cameraColor.a);
            }

            ENDHLSL
        }
    }

    Fallback Off
}