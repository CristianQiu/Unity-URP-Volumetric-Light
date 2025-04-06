#ifndef VOLUMETRIC_FOG_INCLUDED
#define VOLUMETRIC_FOG_INCLUDED

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

int _FrameCount;
uint _CustomAdditionalLightsCount;
float _Distance;
float _BaseHeight;
float _MaximumHeight;
float _GroundHeight;
float _Density;
float _Absortion;
float3 _Tint;
TEXTURE3D(_NoiseTexture);
float _NoiseStrength;
float _NoiseSize;
float3 _NoiseSpeeds;
TEXTURE3D(_DistortionTexture);
float _DistortionStrength;
float _DistortionSize;
float3 _DistortionSpeeds;
int _MaxSteps;

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

//float Curl(float3 pos)
//{
//    float3 c = SAMPLE_TEXTURE3D_LOD(_VFogCurlTexture, sampler_LinearRepeat, (pos + _Time.y * _VFogCurlSpeed) / _VFogCurlSize, 0);
//    c = c * 0.5 - 1;
//    return c * _VFogCurlStrength;
//}

//float GetNoise(float3 pos)
//{
//    pos += Curl(pos);
//    float4 noiseTex = SAMPLE_TEXTURE3D_LOD(_VFogNoiseTexture, sampler_LinearRepeat, (pos + _Time.y * _VFogNoiseSpeed) / _VFogNoiseSize, 0);
//    float noise = saturate(dot(noiseTex, _VFogNoiseWeights));
//    noise = remap(0, 1, _VFogMinMaxNoise.x, _VFogMinMaxNoise.y, noise);
//    return smoothstep(0, 1, noise);
//}

float Noise(float3 posWS)
{
    float3 uvw = (posWS + _Time.y * _NoiseSpeeds) / _NoiseSize;
    float4 noiseSample = SAMPLE_TEXTURE3D(_NoiseTexture, sampler_LinearRepeat, uvw);
    
    float noise = saturate(dot(noiseSample, _NoiseStrength.xxxx));
    
    return noise;
}

float Noise2(float3 posWS)
{
    float3 uvw = (posWS - _Time.y * _NoiseSpeeds) / _NoiseSize;
    float4 noiseSample = SAMPLE_TEXTURE3D(_NoiseTexture, sampler_LinearRepeat, uvw);
    
    float noise = saturate(dot(noiseSample, _NoiseStrength.xxxx));
    
    return noise;
}

float DistortionNoise(float3 posWS)
{
    float3 uvw = (posWS + _Time.y * _DistortionSpeeds) / _DistortionSize;
    float3 distortionNoiseSample = SAMPLE_TEXTURE3D(_DistortionTexture, sampler_LinearRepeat, uvw).rgb;
    
    distortionNoiseSample = distortionNoiseSample * 0.5 - 1.0;
    return distortionNoiseSample * _DistortionStrength;
}

// Gets the fog density at the given world height.
float GetFogDensity(float3 posWS)
{
    float t = saturate((posWS.y - _BaseHeight) / (_MaximumHeight - _BaseHeight));
    t = 1.0 - t;
    t = lerp(t, 0.0, posWS.y < _GroundHeight);

    float d = _Density;
    
#if _NOISE
    float distortionNoise = DistortionNoise(posWS);
    float noise = Noise(posWS + distortionNoise);
    //float noise2 = Noise2(posWS);
    //noise = noise * noise2;
    
    d = _Density * noise;
    //float3 uvw = posWS;
    //uvw *= (0.25 + (_Time.y * 0.008));
    
    //float3 uvw2 = posWS;
    //uvw2 *= (0.25 - (_Time.y * 0.009));
    
    //float4 noise4 = SAMPLE_TEXTURE3D(_NoiseTexture, sampler_LinearRepeat, uvw).rgba;
    //float noise = noise4.r * 0.5 + noise4.g * 0.25 + noise4.b * 0.125 + noise4.a * 0.125;
    
    //float4 noise42 = SAMPLE_TEXTURE3D(_NoiseTexture, sampler_LinearRepeat, uvw2).rgba;
    //float noise2 = noise42.r * 0.5 + noise42.g * 0.25 + noise42.b * 0.125 + noise42.a * 0.125;
    
    //d = _Density - (noise + noise2);
#endif
    
    return d * t;
}

// Gets the main light color at one raymarch step.
float3 GetStepMainLightColor(float3 currPosWS, float phaseMainLight, float density)
{
#if _MAIN_LIGHT_CONTRIBUTION_DISABLED
    return float3(0.0, 0.0, 0.0);
#endif
    Light mainLight = GetMainLight();
    float4 shadowCoord = TransformWorldToShadowCoord(currPosWS);
    mainLight.shadowAttenuation = VolumetricMainLightRealtimeShadow(shadowCoord);
#if _LIGHT_COOKIES
    mainLight.color *= SampleMainLightCookie(currPosWS);
#endif
    return (mainLight.color * _Tint) * (mainLight.shadowAttenuation * phaseMainLight * density * _Scatterings[_CustomAdditionalLightsCount]);
}

// Gets the accumulated color from additional lights at one raymarch step.
float3 GetStepAdditionalLightsColor(float2 uv, float3 currPosWS, float3 rd, float density)
{
#if _ADDITIONAL_LIGHTS_CONTRIBUTION_DISABLED
    return float3(0.0, 0.0, 0.0);
#endif
#if _FORWARD_PLUS
    // Forward+ rendering path needs this data before the light loop.
    InputData inputData = (InputData)0;
    inputData.normalizedScreenSpaceUV = uv;
    inputData.positionWS = currPosWS;
#endif
    float3 additionalLightsColor = float3(0.0, 0.0, 0.0);
                
    // Loop differently through lights in Forward+ while considering Forward and Deferred too.
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
        float newScattering = smoothstep(0.0, _RadiiSq[lightIndex], distToPosMagnitudeSq);
        newScattering *= newScattering;
        newScattering *= _Scatterings[lightIndex];

        // If directional lights are also considered as additional lights when more than 1 is used, ignore the previous code when it is a directional light.
        // They store direction in additionalLightPos.xyz and have .w set to 0, while point and spotlights have it set to 1.
        // newScattering = lerp(1.0, newScattering, additionalLightPos.w);
    
        float phase = CornetteShanksPhaseFunction(_Anisotropies[lightIndex], dot(rd, additionalLight.direction));
        additionalLightsColor += (additionalLight.color * (additionalLight.shadowAttenuation * additionalLight.distanceAttenuation * phase * density * newScattering));
    LIGHT_LOOP_END

    return additionalLightsColor;
}

// Calculates the volumetric fog. Returns the color in the RGB channels and transmittance in alpha.
float4 VolumetricFog(float2 uv, float2 positionCS)
{
    float depth = SampleDownsampledSceneDepth(uv);
    
    float3 ro;
    float3 rd;
    float3 posWS;
    
    float iniOffsetToNearPlane;
    float offsetLength;
    float3 rdPhase;

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

    offsetLength -= iniOffsetToNearPlane;
    float3 roNearPlane = ro + rd * iniOffsetToNearPlane;
    float stepLength = (_Distance - iniOffsetToNearPlane) / (float)_MaxSteps;
    float jitter = stepLength * InterleavedGradientNoise(positionCS, _FrameCount);

#if _MAIN_LIGHT_CONTRIBUTION_DISABLED
    float phaseMainLight = 0.0;
#else
    float phaseMainLight = CornetteShanksPhaseFunction(_Anisotropies[_CustomAdditionalLightsCount], dot(rdPhase, GetMainLight().direction));
#endif
    float minusStepLengthTimesAbsortion = -stepLength * _Absortion;
                
    float3 volumetricFogColor = float3(0.0, 0.0, 0.0);
    float transmittance = 1.0;

    UNITY_LOOP
    for (int i = 0; i < _MaxSteps; ++i)
    {
        float dist = jitter + i * stepLength;

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
        if (density <= 0.0)
            continue;

        float stepAttenuation = exp(minusStepLengthTimesAbsortion * density);
        transmittance *= stepAttenuation;

        float3 mainLightColor = GetStepMainLightColor(currPosWS, phaseMainLight, density);
        float3 additionalLightsColor = GetStepAdditionalLightsColor(uv, currPosWS, rd, density);

        // TODO: Add ambient.
        float3 stepColor = mainLightColor + additionalLightsColor;
        volumetricFogColor += (stepColor * (transmittance * stepLength));
    }

    return float4(volumetricFogColor, transmittance);
}

#endif