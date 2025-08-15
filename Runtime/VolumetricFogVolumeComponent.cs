using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Volume component for the volumetric fog.
/// </summary>
[VolumeComponentMenu("Custom/Volumetric Fog")]
[VolumeRequiresRendererFeatures(typeof(VolumetricFogRendererFeature))]
[SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
public sealed class VolumetricFogVolumeComponent : VolumeComponent, IPostProcessComponent
{
	#region Public Attributes

	[Header("Distances")]
	[Tooltip("The maximum distance from the camera that the fog will be rendered up to.")]
	public ClampedFloatParameter distance = new ClampedFloatParameter(64.0f, 0.0f, 512.0f);
	[Tooltip("The world height at which the fog will have the density specified in the volume.")]
	public FloatParameter baseHeight = new FloatParameter(0.0f, true);
	[Tooltip("The world height at which the fog will have no density at all.")]
	public FloatParameter maximumHeight = new FloatParameter(50.0f, true);
	[Tooltip("When enabled, allows to define a world height. Below it, fog will have no density at all.")]
	public BoolParameter enableGround = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("Below this world height, fog will have no density at all.")]
	public FloatParameter groundHeight = new FloatParameter(0.0f);

	[Header("Lighting")]
	[Tooltip("How dense is the fog.")]
	public ClampedFloatParameter density = new ClampedFloatParameter(0.2f, 0.0f, 1.0f);
	[Tooltip("Value that defines how much the fog attenuates light as distance increases. Lesser values lead to a darker image.")]
	public MinFloatParameter attenuationDistance = new MinFloatParameter(128.0f, 0.05f);
	[Tooltip("When enabled, adaptive probe volumes (APV) will be sampled to contribute to fog.")]
	public BoolParameter enableAPVContribution = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("A weight factor for the light coming from adaptive probe volumes (APV) when the probe volume contribution is enabled.")]
	public ClampedFloatParameter APVContributionWeight = new ClampedFloatParameter(0.5f, 0.0f, 1.0f);
	[Tooltip("When enabled, reflection probes will be sampled to contribute to fog. Forward+ or Deferred+ rendering path is required. It will be ignored and it will not work otherwise.")]
	public BoolParameter enableReflectionProbesContribution = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("A weight factor for the light coming from reflection probes when the reflection probes contribution is enabled.")]
	public ClampedFloatParameter reflectionProbesContributionWeight = new ClampedFloatParameter(0.1f, 0.0f, 1.0f);

	[Header("Main Light")]
	[Tooltip("Disabling this will avoid computing the main light contribution to fog, which in most cases will lead to better performance.")]
	public BoolParameter enableMainLightContribution = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("Higher positive values will make the fog affected by the main light to appear brighter when directly looking to it, while lower negative values will make the fog to appear brighter when looking away from it. The closer the value is closer to 1 or -1, the less the brightness will spread. Most times, positive values higher than 0 and lower than 1 should be used.")]
	public ClampedFloatParameter anisotropy = new ClampedFloatParameter(0.4f, -1.0f, 1.0f);
	[Tooltip("Higher values will make fog affected by the main light to appear brighter.")]
	public ClampedFloatParameter scattering = new ClampedFloatParameter(0.15f, 0.0f, 1.0f);
	[Tooltip("A multiplier color to tint the main light fog.")]
	public ColorParameter tint = new ColorParameter(Color.white, true, false, true);

	[Header("Additional Lights")]
	[Tooltip("Disabling this will avoid computing additional lights contribution to fog, which in most cases will lead to better performance.")]
	public BoolParameter enableAdditionalLightsContribution = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);

	[Header("Noise")]
	[Tooltip("Whether or not to enable the noise feature to break the fog uniformity.")]
	public BoolParameter enableNoise = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("The 3D texture used to add noise. The noise needs to be in the red channel of the texture. You can use your own texture or find the provided one with the package in 'Packages -> URP Volumetric Fog -> Textures'.")]
	public Texture3DParameter noiseTexture = new Texture3DParameter(null, true);
	[Tooltip("The size of noise. Lower values mean higher frequency noise.")]
	public FloatParameter noiseScale = new FloatParameter(5f);
	[Tooltip("These values alter how the noise carves into the uniform fog. Decrease the minimum value to accentuate holes and increase the maximum value to keep the high values of noise closer to the original uniform fog density.")]
	public FloatRangeParameter noiseMinMax = new FloatRangeParameter(new Vector2(0.0f, 1.0f), -2.0f, 2.0f);
	[Tooltip("The speed of noise in each axii.")]
	public Vector3Parameter noiseVelocity = new Vector3Parameter(new Vector3(0.05f, 0.1f, 0.075f));

	[Header("Performance & Quality")]
	[Tooltip("Resolution used to render the volumetric fog. At half resolution, 1/4 of the pixels are rendered. At quarter resolution, 1/16 of the pixels are rendered.")]
	public VolumetricFogResolutionParameter resolution = new VolumetricFogResolutionParameter(VolumetricFogConstants.DefaultResolution);
	[Tooltip("Raymarching steps. Greater values will increase the fog quality at the expense of performance.")]
	public ClampedIntParameter maxSteps = new ClampedIntParameter(128, 8, 256);
	[Tooltip("The number of times that the fog texture will be blurred. Higher values lead to softer volumetric god rays at the cost of some performance.")]
	public ClampedIntParameter blurIterations = new ClampedIntParameter(2, 1, 4);
	[Tooltip("Disabling this will completely remove any feature from the volumetric fog from being rendered at all.")]
	public BoolParameter enabled = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);

	[Header("Render Pass Event")]
	[Tooltip("The URP render pass event to render the volumetric fog.")]
	public VolumetricFogRenderPassEventParameter renderPassEvent = new VolumetricFogRenderPassEventParameter(VolumetricFogConstants.DefaultVolumetricFogRenderPassEvent);

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

		noiseScale.value = Mathf.Max(0.0f, noiseScale.value);
	}

	#endregion

	#region IPostProcessComponent Methods

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	/// <returns></returns>
	public bool IsActive()
	{
		return enabled.value && distance.value > 0.0f && groundHeight.value < maximumHeight.value && density.value > 0.0f;
	}

	#endregion
}