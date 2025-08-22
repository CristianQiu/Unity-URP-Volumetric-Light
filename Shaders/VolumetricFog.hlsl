#ifndef VOLUMETRIC_FOG_INCLUDED
#define VOLUMETRIC_FOG_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/VolumeRendering.hlsl"
#if _APV_CONTRIBUTION
    #if defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2)
        #include "Packages/com.unity.render-pipelines.core/Runtime/Lighting/ProbeVolume/ProbeVolume.hlsl"
    #endif
#endif
#if _CLUSTER_LIGHT_LOOP && _REFLECTION_PROBES_CONTRIBUTION
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#endif
#include "./DeclareDownsampledDepthTexture.hlsl"
#include "./VolumetricShadows.hlsl"
#include "./Utils.hlsl"

#define FOG_HEIGHT_FALLOFF 10.0

int _FrameCount;
uint _CustomAdditionalLightsCount;
float _Distance;
float _BaseHeight;
float _MaximumHeight;
float _GroundHeight;
float _Density;
float _Absortion;
float3 _MainLightTint;
#if _APV_CONTRIBUTION
    #if defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2)
float _APVContributionWeight;
#endif
    #endif
#if _CLUSTER_LIGHT_LOOP && _REFLECTION_PROBES_CONTRIBUTION
float _ReflectionProbesContributionWeight;
#endif
#if _NOISE
TEXTURE3D(_NoiseTexture);
float _NoiseFrequency;
float2 _NoiseMinMax;
float3 _NoiseVelocity;
#endif
#if _NOISE_DISTORTION
TEXTURE3D(_DistortionTexture);
float _DistortionFrequency;
float3 _DistortionIntensity;
float3 _DistortionVelocity;
#endif
int _MaximumSteps;
float _MinimumStepSize;

float _Anisotropies[MAX_VISIBLE_LIGHTS + 1];
float _Scatterings[MAX_VISIBLE_LIGHTS + 1];
float _RadiiSq[MAX_VISIBLE_LIGHTS];

// Computes the ray origin, direction, and returns the reconstructed world position for orthographic projection.
float3 ComputeOrthographicParams(float2 uv, float depth, out float3 ro, out float3 rd)
{
    float4x4 viewMatrix = UNITY_MATRIX_V;
    float2 ndc = uv * 2.0 - 1.0;
    
    rd = normalize(-viewMatrix[2].xyz);
    float3 rightOffset = normalize(viewMatrix[0].xyz) * (ndc.x * unity_OrthoParams.x);
    float3 upOffset = normalize(viewMatrix[1].xyz) * (ndc.y * unity_OrthoParams.y);
    float3 fwdOffset = rd * depth;
    
    float3 posWs = GetCameraPositionWS() + fwdOffset + rightOffset + upOffset;
    ro = posWs - fwdOffset;

    return posWs;
}

// Calculates the initial raymarching parameters.
void CalculateRaymarchingParams(float2 uv, out float3 ro, out float3 rd, out float iniOffsetToNearPlane, out float offsetLength, out float3 rdPhase)
{
    float depth = SampleDownsampledSceneDepth(uv);
    float3 posWS;
    
    UNITY_BRANCH
    if (unity_OrthoParams.w <= 0)
    {
        ro = GetCameraPositionWS();
#if !UNITY_REVERSED_Z
        depth = lerp(UNITY_NEAR_CLIP_VALUE, 1.0, depth);
#endif
        posWS = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
        float3 offset = posWS - ro;
        offsetLength = length(offset);
        rd = offset / offsetLength;
        rdPhase = rd;
        
        // In perspective, ray direction should vary in length depending on which fragment we are at.
        float3 camFwd = normalize(-UNITY_MATRIX_V[2].xyz);
        float cos = dot(camFwd, rd);
        float fragElongation = 1.0 / cos;
        iniOffsetToNearPlane = fragElongation * _ProjectionParams.y;
    }
    else
    {
        depth = LinearEyeDepthOrthographic(depth);
        posWS = ComputeOrthographicParams(uv, depth, ro, rd);
        offsetLength = depth;
        
        // Fake the ray direction that will be used to calculate the phase, so we can still use anisotropy in orthographic mode.
        rdPhase = normalize(posWS - GetCameraPositionWS());
        iniOffsetToNearPlane = _ProjectionParams.y;
    }
}

// Gets the main light phase function.
float GetMainLightPhase(float3 rd)
{
#if _MAIN_LIGHT_CONTRIBUTION
    return CornetteShanksPhaseFunction(_Anisotropies[_CustomAdditionalLightsCount], dot(rd, GetMainLight().direction));
#else
    return 0.0;
#endif
}

// Gets the noise value based on the world position.
float GetNoise(float3 posWS)
{
    float3 distortion = float3(0.0, 0.0, 0.0);

#if _NOISE_DISTORTION
    float3 uvwDistortion = (posWS * _DistortionFrequency) + (_Time.y * _DistortionVelocity);
    distortion = SAMPLE_TEXTURE3D_LOD(_DistortionTexture, sampler_LinearRepeat, uvwDistortion, 0).rgb;
    distortion *= _DistortionIntensity;
#endif
#if _NOISE
    float3 uvwNoise = (posWS * _NoiseFrequency) + (_Time.y * _NoiseVelocity) + distortion;
    float noise = SAMPLE_TEXTURE3D_LOD(_NoiseTexture, sampler_LinearRepeat, uvwNoise, 0).r;
    noise = RemapSaturate(0.0, 1.0, _NoiseMinMax.x, _NoiseMinMax.y, noise);
    return noise;
#endif
 
    return 1.0;
}

// Gets the fog density at the given world height.
float GetFogDensity(float3 posWS)
{
    if (posWS.y < _GroundHeight || posWS.y > _MaximumHeight)
        return 0.0;
    
    float range = abs(_MaximumHeight - _BaseHeight);
    float topFactor = exp(-range / FOG_HEIGHT_FALLOFF);
    float relativeExp = exp(-(posWS.y - _BaseHeight) / FOG_HEIGHT_FALLOFF);
    float normalizedDensity = InverseLerp(topFactor, 1.0, relativeExp);

    return normalizedDensity * GetNoise(posWS) * _Density;
}

// Gets the GI evaluation from the adaptive probe volume at one raymarch step.
float3 GetStepAdaptiveProbeVolumeEvaluation(float2 uv, float3 posWS)
{
    float3 apvDiffuseGI = float3(0.0, 0.0, 0.0);
    
#if _APV_CONTRIBUTION
    #if defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2)
        EvaluateAdaptiveProbeVolume(posWS, uv * _ScreenSize.xy, apvDiffuseGI);
        apvDiffuseGI = apvDiffuseGI * _APVContributionWeight;
    #endif
#endif
 
    return apvDiffuseGI;
}

// Gets the reflection probe evaluation at one raymarch step.
float3 GetStepReflectionProbesEvaluation(float2 uv, float3 currPosWS, float3 rd)
{
#if _CLUSTER_LIGHT_LOOP && _REFLECTION_PROBES_CONTRIBUTION
    return CalculateIrradianceFromReflectionProbes(rd, currPosWS, 1.0, uv) * _ReflectionProbesContributionWeight;
#endif
    return float3(0.0, 0.0, 0.0);
}

// Gets the main light color at one raymarch step.
float3 GetStepMainLightColor(float3 currPosWS, float phaseMainLight)
{
#if _MAIN_LIGHT_CONTRIBUTION
    Light mainLight = GetMainLight();
    float4 shadowCoord = TransformWorldToShadowCoord(currPosWS);
    mainLight.shadowAttenuation = VolumetricMainLightRealtimeShadow(shadowCoord);
#if _LIGHT_COOKIES
    mainLight.color *= SampleMainLightCookie(currPosWS);
#endif
    return (mainLight.color * _MainLightTint) * (mainLight.shadowAttenuation * phaseMainLight * _Scatterings[_CustomAdditionalLightsCount]);
#endif
    return float3(0.0, 0.0, 0.0);
}

// Gets the accumulated color from additional lights at one raymarch step.
float3 GetStepAdditionalLightsColor(float2 uv, float3 currPosWS, float3 rd)
{
#if _ADDITIONAL_LIGHTS_CONTRIBUTION
#if _CLUSTER_LIGHT_LOOP
    InputData inputData = (InputData)0;
    inputData.normalizedScreenSpaceUV = uv;
    inputData.positionWS = currPosWS;
#endif
    float3 additionalLightsColor = float3(0.0, 0.0, 0.0);
                
    LIGHT_LOOP_BEGIN(_CustomAdditionalLightsCount)
        UNITY_BRANCH
        if (_Scatterings[lightIndex] <= 0.0)
            continue;

        Light additionalLight = GetAdditionalPerObjectLight(lightIndex, currPosWS);
        additionalLight.shadowAttenuation = VolumetricAdditionalLightRealtimeShadow(lightIndex, currPosWS, additionalLight.direction);
#if _LIGHT_COOKIES
        additionalLight.color *= SampleAdditionalLightCookie(lightIndex, currPosWS);
#endif
        // See universal\ShaderLibrary\RealtimeLights.hlsl - GetAdditionalPerObjectLight.
#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
        float4 additionalLightPos = _AdditionalLightsBuffer[lightIndex].position;
#else
        float4 additionalLightPos = _AdditionalLightsPosition[lightIndex];
#endif
        // This is useful for both spotlights and pointlights. For the latter it is specially true when the point light is inside some geometry and casts shadows.
        // Gradually reduce additional lights scattering to zero at their origin to try to avoid flicker-aliasing.
        float3 distToPos = additionalLightPos.xyz - currPosWS;
        float distToPosMagnitudeSq = dot(distToPos, distToPos);

        // Ease out towards the origin of the light to minimize potential seams, specially when the remapping starts taking over.
        float t = InverseLerp(0.0, _RadiiSq[lightIndex], distToPosMagnitudeSq);
        float newScattering = 1.0 - pow(1.0 - t, 8.0);
        
        // If directional lights are also considered as additional lights when more than 1 is used, ignore the previous code when it is a directional light.
        // They store direction in additionalLightPos.xyz and have .w set to 0, while point and spotlights have it set to 1.
        // newScattering = lerp(1.0, newScattering, additionalLightPos.w);
        newScattering *= _Scatterings[lightIndex];
    
        float phase = CornetteShanksPhaseFunction(_Anisotropies[lightIndex], dot(rd, additionalLight.direction));
        additionalLightsColor += (additionalLight.color * (additionalLight.shadowAttenuation * additionalLight.distanceAttenuation * phase * newScattering));
    LIGHT_LOOP_END

    return additionalLightsColor;
#endif
    return float3(0.0, 0.0, 0.0);
}

// Calculates the volumetric fog. Returns the color in the RGB channels and transmittance in alpha.
float4 VolumetricFog(float2 uv, float2 positionCS)
{
    float3 ro;
    float3 rd;
    float iniOffsetToNearPlane;
    float offsetLength;
    float3 rdPhase;

    CalculateRaymarchingParams(uv, ro, rd, iniOffsetToNearPlane, offsetLength, rdPhase);

    float3 roNearPlane = ro + rd * iniOffsetToNearPlane;

    // Clamp the length we raymarch to be in between camera near plane and the minimum of depth buffer or _Distance.
    offsetLength = min(max(_Distance - iniOffsetToNearPlane, 0.0), offsetLength - iniOffsetToNearPlane);

    // Then recalculate the steps to be clamped to a minimum step size, because we do not want to step hundred of times when a column is just a few centimeters away in the depth buffer.
    float stepSize = offsetLength / (float)_MaximumSteps;
    stepSize = max(stepSize, _MinimumStepSize);
    int actualSteps = (int)ceil(offsetLength / stepSize);

    // Calculate the distance to start at, with some jitter.
    float dist = stepSize * IGN(positionCS, _FrameCount);

    float phaseMainLight = GetMainLightPhase(rdPhase);
    float minusStepSizeTimesAbsortion = -stepSize * _Absortion;
                
    float3 volumetricFogColor = float3(0.0, 0.0, 0.0);
    float3 environmentColor = _GlossyEnvironmentColor.rgb;
    float transmittance = 1.0;

    UNITY_LOOP
    for (int i = 0; i < actualSteps; ++i)
    {
        UNITY_BRANCH
        if (dist >= offsetLength)
            break;        

        // We are making the space between the camera position and the near plane "non existant", as if fog did not exist there.
        // However, it removes a lot of noise when in closed environments with an attenuation that makes the scene darker
        // and certain combinations of field of view, raymarching resolution and camera near plane.
        // In those edge cases, it looks so much better, specially when near plane is higher than the minimum (0.01) allowed.
        float3 currPosWS = roNearPlane + rd * dist;
        float density = GetFogDensity(currPosWS);
                    
        UNITY_BRANCH
        if (density <= 0.001)
        {
            dist += stepSize;
            continue;
        }

        float3 apvColor = GetStepAdaptiveProbeVolumeEvaluation(uv, currPosWS);
        float3 reflectionProbesColor = GetStepReflectionProbesEvaluation(uv, currPosWS, rd);
        float3 mainLightColor = GetStepMainLightColor(currPosWS, phaseMainLight);
        float3 additionalLightsColor = GetStepAdditionalLightsColor(uv, currPosWS, rd);

        float stepAttenuation = exp(minusStepSizeTimesAbsortion * density);
        float transmittanceFactor = (1.0 - stepAttenuation) / max(density * _Absortion, FLOAT_GREATER_EPSILON);

        float3 stepColor = (apvColor + reflectionProbesColor + mainLightColor + additionalLightsColor) * transmittance * transmittanceFactor * density;
        volumetricFogColor += stepColor;

        transmittance *= stepAttenuation;
        dist += stepSize;

        // TODO: Break out when transmittance reaches low threshold and remap the transmittance when doing so.
        // It does not make sense right now because the fog does not properly support transparency, so having dense fog leads to issues.
    }

    return float4(volumetricFogColor, transmittance);
}

#endif