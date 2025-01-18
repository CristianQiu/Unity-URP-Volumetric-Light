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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/VolumeRendering.hlsl"
            #include "./DeclareDownsampledDepthTexture.hlsl"
            #include "./VolumetricShadows.hlsl"
            #include "./ProjectionUtils.hlsl"

            #pragma multi_compile _ _FORWARD_PLUS

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES

            #pragma multi_compile_local_fragment _ _MAIN_LIGHT_CONTRIBUTION_DISABLED
            #pragma multi_compile_local_fragment _ _ADDITIONAL_LIGHTS_CONTRIBUTION_DISABLED

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
            float3 _Tint;
            int _MaxSteps;

            float _Anisotropies[MAX_VISIBLE_LIGHTS + 1];
            float _Scatterings[MAX_VISIBLE_LIGHTS + 1];
            float _RadiiSq[MAX_VISIBLE_LIGHTS];

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
                // get the main light and set its data
                Light mainLight = GetMainLight();
                float4 shadowCoord = TransformWorldToShadowCoord(currPosWS);
                mainLight.shadowAttenuation = VolumetricMainLightRealtimeShadow(shadowCoord);
#if _LIGHT_COOKIES
                // when light cookies are enabled and one is set for the main light, also factor it
                mainLight.color *= SampleMainLightCookie(currPosWS);
#endif
                // return the final color
                return (mainLight.color * _Tint) * (mainLight.shadowAttenuation * phaseMainLight * density * _Scatterings[_CustomAdditionalLightsCount]);
            }

            // Gets the accumulated color from additional lights at one raymarch step.
            float3 GetStepAdditionalLightsColor(float2 uv, float3 currPosWS, float3 rd, float density)
            {
#if _ADDITIONAL_LIGHTS_CONTRIBUTION_DISABLED
                return float3(0.0, 0.0, 0.0);
#endif
#if _FORWARD_PLUS
                // Forward+ rendering path needs this data before the light loop
                InputData inputData = (InputData)0;
                inputData.normalizedScreenSpaceUV = uv;
                inputData.positionWS = currPosWS;
#endif
                // initialize the accumulated color from additional lights
                float3 additionalLightsColor = float3(0.0, 0.0, 0.0);   
                
                // loop differently through lights in Forward+ while considering Forward and Deferred too
                LIGHT_LOOP_BEGIN(_CustomAdditionalLightsCount)
                    float additionalLightScattering = _Scatterings[lightIndex];

                    UNITY_BRANCH
                    if (additionalLightScattering <= 0.0)
                        continue;

                    float additionalLightAnisotropy = _Anisotropies[lightIndex];
                    float additionalLightRadiusSq = _RadiiSq[lightIndex];

                    Light additionalLight = GetAdditionalPerObjectLight(lightIndex, currPosWS);
                    additionalLight.shadowAttenuation = VolumetricAdditionalLightRealtimeShadow(lightIndex, currPosWS, additionalLight.direction);
#if _LIGHT_COOKIES
                    // when light cookies are enabled and a cookie is set for this additional light also factor it
                    additionalLight.color *= SampleAdditionalLightCookie(lightIndex, currPosWS);
#endif
                    // calculate the phase function for this additional light
                    float phaseAdditionalLight = CornetteShanksPhaseFunction(additionalLightAnisotropy, dot(rd, additionalLight.direction));

                    // See universal\ShaderLibrary\RealtimeLights.hlsl - GetAdditionalPerObjectLight
#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
                    float4 additionalLightPos = _AdditionalLightsBuffer[lightIndex].position;
#else
                    float4 additionalLightPos = _AdditionalLightsPosition[lightIndex];
#endif
                    // Note: This is useful for both spotlights and pointlights. For the latter it is specially true when the point light is inside some geometry and casts shadows.
                    // Gradually reduce additional lights scattering to zero at their origin to try to avoid flicker-aliasing.
                    float3 distToPos = additionalLightPos.xyz - currPosWS;
                    float distToPosMagnitudeSq = dot(distToPos, distToPos);
                    float newScattering = smoothstep(0.0, additionalLightRadiusSq, distToPosMagnitudeSq) * additionalLightScattering;

                    // I think this looks better, it hides the subtle seam that is created due to different rate of increase/decrease
                    newScattering = newScattering * newScattering;
                    
                    // Note: If directional lights are also considered as additional lights when more than 1 is used, ignore the previous code when it is a directional light.
                    // They store direction in additionalLightPos.xyz and have .w set to 0, while point and spotlights have it set to 1.
                    // newScattering = lerp(1.0, newScattering, additionalLightPos.w);

                    // accumulate the total color for additional lights
                    additionalLightsColor += (additionalLight.color * (additionalLight.shadowAttenuation * additionalLight.distanceAttenuation * phaseAdditionalLight * density * newScattering));
                LIGHT_LOOP_END

                return additionalLightsColor;
            }

            // Computes the needed ray origin and direction for orthographic projection.
            float3 ComputeOrthoWPos(float2 uv, float depth, out float3 ro, out float3 rd)
            {
                float2 ndc = uv * 2.0 - 1.0;

                float4x4 viewMatrix = UNITY_MATRIX_V;

                float3 camRightWs = normalize(viewMatrix[0].xyz);
                float3 camUpWs = normalize(viewMatrix[1].xyz);
                float3 camFwdWs = normalize(-viewMatrix[2].xyz);

                float3 posWs = GetCameraPositionWS() + 
                (camRightWs * (ndc.x * unity_OrthoParams.x)) +
                (camUpWs * (ndc.y * unity_OrthoParams.y)) +
                (camFwdWs * depth);

                rd = camFwdWs;
                ro = posWs - rd * depth;

                return posWs;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // prepare the ray origin and direction
                float depth = SampleDownsampledSceneDepth(input.texcoord);
                float3 ro;
                float3 rd;
                float3 posWS;
                float offsetLength;
                float3 rdPhase;

                UNITY_BRANCH
                if (unity_OrthoParams.w <= 0)
                {
                    ro = GetCameraPositionWS();
#if !UNITY_REVERSED_Z
                    depth = lerp(UNITY_NEAR_CLIP_VALUE, 1.0, depth);
#endif
                    posWS = ComputeWorldSpacePosition(input.texcoord, depth, UNITY_MATRIX_I_VP);
                    float3 offset = posWS - ro;
                    offsetLength = length(offset);
                    rd = offset / offsetLength;
                    rdPhase = rd;
                }
                else
                {
                    depth = LinearEyeDepthOrthographic(depth);
                    posWS = ComputeOrthoWPos(input.texcoord, depth, ro, rd);
                    offsetLength = depth;
                    rdPhase = rd;//normalize(posWS - GetCameraPositionWS()); // fake fase?
                }

                // calculate the step length and jitter
                float stepLength = _Distance / (float)_MaxSteps;
                float jitter = stepLength * InterleavedGradientNoise(input.positionCS.xy, _FrameCount);

#if _MAIN_LIGHT_CONTRIBUTION_DISABLED
                float phaseMainLight = 0.0;
#else
                // calculate the phase function for the main light and part of the extinction factor
                // note that we fake the view ray dir for orthographic, as it would otherwise mean that the main light will always have the same phase
                float phaseMainLight = CornetteShanksPhaseFunction(_Anisotropies[_CustomAdditionalLightsCount], dot(rdPhase, GetMainLight().direction));
#endif
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

                    // calculate density
                    float density = GetFogDensity(currPosWS.y);
                    
                    // keep marching when there is not enough density
                    UNITY_BRANCH
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

            #pragma vertex Vert
            #pragma fragment Frag

#if UNITY_VERSION < 202320
            float4 _BlitTexture_TexelSize;
#endif

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

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float4 volumetricFog = DepthAwareUpsample(input.texcoord);
                float4 cameraColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, input.texcoord);

                return float4(cameraColor.rgb * volumetricFog.a + volumetricFog.rgb, cameraColor.a);
            }

            ENDHLSL
        }
    }

    SubShader
    {
        Tags
        { 
            "RenderPipeline" = "UniversalPipeline"
        }

        UsePass "Hidden/VolumetricFog/VOLUMETRICFOGRENDER"

        UsePass "Hidden/VolumetricFog/VOLUMETRICFOGHORIZONTALBLUR"
            
        UsePass "Hidden/VolumetricFog/VOLUMETRICFOGVERTICALBLUR"

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

            #pragma vertex Vert
            #pragma fragment Frag

            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float4 volumetricFog = DepthAwareUpsample(input.texcoord);
                float4 cameraColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, input.texcoord);

                return float4(cameraColor.rgb * volumetricFog.a + volumetricFog.rgb, cameraColor.a);
            }

            ENDHLSL
        }
    }

    Fallback Off
}