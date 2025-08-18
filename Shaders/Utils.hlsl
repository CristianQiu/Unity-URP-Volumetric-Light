#ifndef UTILS_INCLUDED
#define UTILS_INCLUDED

// Gets where the value lies within the range [a, b]. At 0, value is at a, at 1, value is at b.
float InverseLerp(float a, float b, float value)
{
    return saturate(value - a) / (b - a);
}

// Remaps the original value from one range to another.
float RemapSaturate(float origMin, float origMax, float destMin, float destMax, float origVal)
{
    float t = InverseLerp(origMin, origMax, origVal);

    return lerp(destMin, destMax, t);
}

// Returns the linear eye depth for orthographic projection.
float LinearEyeDepthOrthographic(float rawDepth)
{
#if UNITY_REVERSED_Z
    return lerp(_ProjectionParams.z, _ProjectionParams.y, rawDepth);
#else
    return lerp(_ProjectionParams.y, _ProjectionParams.z, rawDepth);
#endif
}

// Returns the linear eye depth considering the camera projection type.
float LinearEyeDepthConsiderProjection(float rawDepth)
{
    float perspectiveDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
    float orthographicDepth = LinearEyeDepthOrthographic(rawDepth);

    return lerp(perspectiveDepth, orthographicDepth, unity_OrthoParams.w);
}

// From Next Generation Post Processing in Call of Duty: Advanced Warfare [Jimenez 2014]
// http://advances.realtimerendering.com/s2014/index.html
float IGN(float2 pixCoords, int frameCount)
{
    const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    const float2 frameMagicScale = float2(5.588238, 5.588238);
    pixCoords += frameCount * frameMagicScale;
    return frac(magic.z * frac(dot(pixCoords, magic.xy)));
}

#endif