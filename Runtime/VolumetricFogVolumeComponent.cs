using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Volume component for the volumetric fog.
/// </summary>
#if UNITY_2023_1_OR_NEWER
[VolumeComponentMenu("Custom/Volumetric Fog")]
#if UNITY_2023_3_OR_NEWER
[VolumeRequiresRendererFeatures(typeof(VolumetricFogRendererFeature))]
#endif
[SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
#else
[VolumeComponentMenuForRenderPipeline("Custom/Volumetric Fog", typeof(UniversalRenderPipeline))]
#endif
public sealed class VolumetricFogVolumeComponent : VolumeComponent, IPostProcessComponent
{
	#region Public Attributes

	[Header("Distances")]
	public ClampedFloatParameter distance = new ClampedFloatParameter(128.0f, 16.0f, 512.0f, false);
	public FloatParameter baseHeight = new FloatParameter(0.0f, true);
	public FloatParameter maximumHeight = new FloatParameter(50.0f, true);

	[Header("Lighting")]
	public ClampedFloatParameter density = new ClampedFloatParameter(0.2f, 0.0f, 1.0f, false);
	public MinFloatParameter attenuationDistance = new MinFloatParameter(128.0f, 0.05f, false);
	public ColorParameter tint = new ColorParameter(Color.white, true, false, true, false);

	[Header("Main Light")]
	public ClampedFloatParameter mainLightAnisotropy = new ClampedFloatParameter(0.4f, 0.0f, 0.99f, false);
	public ClampedFloatParameter mainLightScattering = new ClampedFloatParameter(0.15f, 0.0f, 1.0f, false);

	[Header("Additional Lights")]
	public ClampedFloatParameter additionalLightsAnisotropy = new ClampedFloatParameter(0.25f, 0.0f, 0.99f, false);
	public ClampedFloatParameter additionalLightsScattering = new ClampedFloatParameter(1.0f, 0.0f, 32.0f, false);
	public ClampedFloatParameter additionalLightsRadius = new ClampedFloatParameter(0.5f, 0.0f, 1.0f, false);

	[Header("Performance & Quality")]
	public ClampedIntParameter maxSteps = new ClampedIntParameter(64, 8, 128, false);
	public ClampedIntParameter blurIterations = new ClampedIntParameter(2, 1, 4, false);
	public BoolParameter enabled = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);

	#endregion

	#region Initialization Methods

	public VolumetricFogVolumeComponent() : base()
	{
		displayName = "Volumetric Fog";
	}

	#endregion

	#region Volume Component Methods

	private void OnValidate()
	{
		maximumHeight.overrideState = baseHeight.overrideState;
		maximumHeight.value = Mathf.Max(baseHeight.value, maximumHeight.value);
		baseHeight.value = Mathf.Min(baseHeight.value, maximumHeight.value);
	}

	#endregion

	#region IPostProcessComponent Methods

#if !UNITY_2023_3_OR_NEWER

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	/// <returns></returns>
	/// <exception cref="System.NotImplementedException"></exception>
	public bool IsTileCompatible()
	{
		return true;
	}

#endif

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	/// <returns></returns>
	public bool IsActive()
	{
		return enabled.value;
	}

	#endregion
}