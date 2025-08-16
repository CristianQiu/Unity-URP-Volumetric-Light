#ifndef UTILS_INCLUDED
#define UTILS_INCLUDED

// Gets where the value lies within the range [a, b]. At 0, value is at a, at 1, value is at b.
float InverseLerp(float value, float a, float b)
{
    return saturate(value - a) / (b - a);
}

// Remaps the original value from one range to another.
float RemapSaturate(float origVal, float origMin, float origMax, float destMin, float destMax)
{
    float t = InverseLerp(origVal, origMin, origMax);

    return lerp(destMin, destMax, t);
}

#endif