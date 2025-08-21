using System;
using UnityEngine.Rendering;

/// <summary>
/// A volume parameter that holds a VolumetricFogNoiseMode value.
/// </summary>
[Serializable]
public sealed class VolumetricFogNoiseModeParameter : VolumeParameter<VolumetricFogNoiseMode>
{
	/// <summary>
	/// Creates a new VolumetricFogNoiseModeParameter instance.
	/// </summary>
	/// <param name="value"></param>
	/// <param name="overrideState"></param>
	public VolumetricFogNoiseModeParameter(VolumetricFogNoiseMode value, bool overrideState = false) : base(value, overrideState)
	{
	}
}