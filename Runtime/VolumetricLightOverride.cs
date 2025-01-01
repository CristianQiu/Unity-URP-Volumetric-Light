using UnityEngine;

/// <summary>
/// This is a component that can be added to lights to override some parameters that will affect how
/// this light is considered for the volumetric fog effect.
/// </summary>
public sealed class VolumetricLightOverride : MonoBehaviour
{
	#region Private Attributes

	[Header("Override Settings")]
	[Range(0.0f, 0.99f)]
	[SerializeField]
	private float anisotropy = 0.25f;
	[Range(0.0f, 16.0f)]
	[SerializeField]
	private float scattering = 1.0f;
	[Range(0.0f, 1.0f)]
	[SerializeField]
	private float radius = 0.2f;

	#endregion

	#region Properties

	public float Anisotropy
	{
		get { return anisotropy; }
		set { anisotropy = Mathf.Clamp01(value); }
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