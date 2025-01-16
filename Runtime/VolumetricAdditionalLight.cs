using UnityEngine;
using UnityEngine.Rendering.Universal;

/// <summary>
/// This is a component that can be added to additional lights to set the parameters that will
/// affect how this light is considered for the volumetric fog effect.
/// </summary>
[DisallowMultipleComponent]
[RequireComponent(typeof(Light), typeof(UniversalAdditionalLightData))]
public sealed class VolumetricAdditionalLight : MonoBehaviour
{
	#region Private Attributes

	[Tooltip("Higher values will make the fog affected by this light to appear brighter when directly looking to the light source. The higher the value the less the brightness will spread when looking away from the light.")]
	[Range(0.0f, 0.99f)]
	[SerializeField] private float anisotropy = 0.25f;
	[Tooltip("Higher values will make fog affected by this light to appear brighter.")]
	[Range(0.0f, 16.0f)]
	[SerializeField] private float scattering = 1.0f;
	[Tooltip("Sets a falloff radius for this light. A higher value reduces noise towards the origin of the light.")]
	[Range(0.0f, 1.0f)]
	[SerializeField] private float radius = 0.2f;

	#endregion

	#region Properties

	public float Anisotropy
	{
		get { return anisotropy; }
		set { anisotropy = Mathf.Clamp(value, 0.0f, 0.99f); }
	}

	public float Scattering
	{
		get { return scattering; }
		set { scattering = Mathf.Clamp(value, 0.0f, 16.0f); }
	}

	public float Radius
	{
		get { return radius; }
		set { radius = Mathf.Clamp01(value); }
	}

	#endregion
}