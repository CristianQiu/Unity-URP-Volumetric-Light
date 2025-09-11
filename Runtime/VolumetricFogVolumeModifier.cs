using UnityEngine;

/// <summary>
/// This is a component that modifies the volumetric fog density within a spherical area.
/// </summary>
public sealed class VolumetricFogVolumeModifier : MonoBehaviour
{
	#region Private Attributes

	private static readonly Color DebugColor = Color.chartreuse;

	[Min(0.0f)]
	[SerializeField] private float radius = 2.5f;
	[Min(0.0f)]
	[SerializeField] private float fallOff = 0.05f;
	[Min(0.0f)]
	[SerializeField] private float densityMultiplier = 10.0f;

	#endregion

	#region Properties

	public float Radius
	{
		get { return radius; }
		set { radius = Mathf.Max(value, 0.0f); }
	}

	public float FallOff
	{
		get { return fallOff; }
		set { fallOff = Mathf.Max(value, 0.0f); }
	}

	public float DensityMultiplier
	{
		get { return densityMultiplier; }
		set { densityMultiplier = Mathf.Max(value, 0.0f); }
	}

	#endregion

	#region MonoBehaviour Methods

	private void OnDrawGizmos()
	{
		Gizmos.color = DebugColor;
		Gizmos.DrawWireSphere(transform.position, radius);
	}

	#endregion
}