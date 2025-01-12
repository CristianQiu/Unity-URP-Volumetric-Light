#ifndef PROJECTION_UTILS_INCLUDED
#define PROJECTION_UTILS_INCLUDED

// Returns the linear eye depth for orthographic projection.
float LinearEyeDepthOrthographic(float rawDepth)
{
    return lerp(_ProjectionParams.y, _ProjectionParams.z, rawDepth);
}

// Returns the linear eye depth considering the current camera projection type.
float LinearEyeDepthConsiderProjection(float rawDepth)
{
    float perspectiveDepth = LinearEyeDepth(fullResDepth, _ZBufferParams);
    float orthographicDepth = LinearEyeDepthOrthographic(rawDepth);

    return lerp(perspectiveDepth, orthographicDepth, unity_OrthoParams.w);
}

#endif