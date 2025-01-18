#ifndef PROJECTION_UTILS_INCLUDED
#define PROJECTION_UTILS_INCLUDED

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

#endif