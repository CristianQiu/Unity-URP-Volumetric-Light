using UnityEngine;
using UnityEngine.Rendering.Universal;

/// <summary>
/// This is a component that can be added to additional lights to set the parameters that will
/// affect how this light is considered for the volumetric fog.
/// </summary>
[DisallowMultipleComponent]
[RequireComponent(typeof(Light), typeof(UniversalAdditionalLightData))]
public sealed class VolumetricAdditionalLight : MonoBehaviour
{
	#region Private Attributes

	[Tooltip("The scattering distribution. The closer the value is to 1 or -1, the less the light will spread through fog and the brighter it will be towards the light origin.")]
	[Range(-1.0f, 1.0f)]
	[SerializeField] private float anisotropy = 0.25f;
	[Tooltip("Higher values will make fog affected by this light to appear brighter.")]
	[Range(0.0f, VolumetricFogConstants.MaxScatteringMultiplier)]
	[SerializeField] private float scattering = 1.0f;
	[Tooltip("Sets a falloff radius for this light. A higher value reduces fog noisiness towards the origin of the light.")]
	[Range(0.0f, VolumetricFogConstants.MaxAdditionalLightRadius)]
	[SerializeField] private float radius = 0.0f;

	#endregion

	#region Properties

	public float Anisotropy
	{
		get { return anisotropy; }
		set { anisotropy = Mathf.Clamp(value, -1.0f, 1.0f); }
	}

	public float Scattering
	{
		get { return scattering; }
		set { scattering = Mathf.Clamp(value, 0.0f, VolumetricFogConstants.MaxScatteringMultiplier); }
	}

	public float Radius
	{
		get { return radius; }
		set { radius = Mathf.Clamp(value, 0.0f, VolumetricFogConstants.MaxAdditionalLightRadius); }
	}

	#endregion
}