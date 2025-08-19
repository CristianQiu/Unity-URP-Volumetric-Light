using System;
using UnityEngine.Rendering;

/// <summary>
/// A volume parameter that holds a VolumetricFogResolution value.
/// </summary>
[Serializable]
public sealed class VolumetricFogResolutionParameter : VolumeParameter<VolumetricFogResolution>
{
	/// <summary>
	/// Creates a new VolumetricFogResolutionParameter instance.
	/// </summary>
	/// <param name="value"></param>
	/// <param name="overrideState"></param>
	public VolumetricFogResolutionParameter(VolumetricFogResolution value, bool overrideState = false) : base(value, overrideState)
	{
	}
}