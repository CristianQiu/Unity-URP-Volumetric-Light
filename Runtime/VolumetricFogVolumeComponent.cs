using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Volume component for the volumetric fog.
/// </summary>
[VolumeComponentMenu("Custom/Volumetric Fog")]
[VolumeRequiresRendererFeatures(typeof(VolumetricFogRendererFeature))]
[SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
[DisplayInfo(name = "Volumetric Fog", order = 0)]
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
	[Tooltip("Below this world height, fog will have no density at all.")]
	public FloatParameter groundHeight = new FloatParameter(-100000.0f);

	[Header("Lighting")]
	[Tooltip("How dense is the fog.")]
	public ClampedFloatParameter density = new ClampedFloatParameter(0.25f, 0.0f, 1.0f);
	[Tooltip("Value that defines how much the fog attenuates light as distance increases. Lesser values lead to a darker image.")]
	public MinFloatParameter attenuationDistance = new MinFloatParameter(128.0f, 0.025f);
	[Tooltip("Gives some extra ambience color, as none is considered besides lights, APVs, or reflection probes. Alpha channel determines intensity.")]
	public ColorParameter ambienceColor = new ColorParameter(Color.black, true, true, true);
	[Tooltip("Disabling this will avoid computing the main light contribution to fog.")]
	public BoolParameter mainLightContribution = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("Higher positive values will make the fog affected by the main light to appear brighter when directly looking to it, while lower negative values will make the fog to appear brighter when looking away from it. The closer the value is closer to 1 or -1, the less the brightness will spread. Most times, positive values higher than 0 and lower than 1 should be used.")]
	public ClampedFloatParameter mainLightAnisotropy = new ClampedFloatParameter(0.4f, -1.0f, 1.0f);
	[Tooltip("Higher values will make fog affected by the main light to appear brighter.")]
	public ClampedFloatParameter mainLightScattering = new ClampedFloatParameter(0.75f, 0.0f, 16.0f);
	[Tooltip("A multiplier color to tint the main light fog.")]
	public ColorParameter mainLightTint = new ColorParameter(Color.white, true, false, true);
	[Tooltip("Disabling this will avoid computing additional lights contribution to fog.")]
	public BoolParameter additionalLightsContribution = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("When enabled, adaptive probe volumes (APV) will be sampled to contribute to fog.")]
	public BoolParameter APVContribution = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("A weight factor for the light coming from adaptive probe volumes (APV) when the probe volume contribution is enabled.")]
	public ClampedFloatParameter APVContributionWeight = new ClampedFloatParameter(0.5f, 0.0f, 1.0f);
	[Tooltip("When enabled, reflection probes will be sampled to contribute to fog. Forward+ or deferred+ rendering path is required.")]
	public BoolParameter reflectionProbesContribution = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("A weight factor for the light coming from reflection probes when the reflection probes contribution is enabled.")]
	public ClampedFloatParameter reflectionProbesContributionWeight = new ClampedFloatParameter(0.1f, 0.0f, 1.0f);

	[Header("Noise")]
	[Tooltip("The modes to use noise to modify the density of volumetric fog. Read the tooltips from each of the texture parameters to understand the channels set up and where to access the default provided resource.")]
	public VolumetricFogNoiseModeParameter noiseMode = new VolumetricFogNoiseModeParameter(VolumetricFogConstants.DefaultVolumetricFogNoiseMode, true);
	[Tooltip("The 3D texture used to add noise. The noise needs to be in the R channel of the texture. You can use your own texture or find the provided one with the package in 'Packages -> URP Volumetric Fog -> Textures -> Noise'.")]
	public Texture3DParameter noiseTexture = new Texture3DParameter(null, true);
	[Tooltip("The size of noise. Lower values mean higher frequency noise.")]
	public FloatParameter noiseScale = new FloatParameter(2.5f);
	[Tooltip("These values alter how the noise carves into fog. Decrease the minimum value to accentuate holes and increase the maximum value accentuate the distance between the minimum and maximum value, increasing the contrast in noise.")]
	public FloatRangeParameter noiseMinMax = new FloatRangeParameter(new Vector2(-0.75f, 2.5f), -2.5f, 2.5f);
	[Tooltip("The speed of noise in each axii.")]
	public Vector3Parameter noiseVelocity = new Vector3Parameter(new Vector3(0.1f, -0.15f, -0.05f));
	[Tooltip("The 3D texture used to add distortion to the original noise. The distortion needs to be in the RGB channel of the texture. You can use your own texture or find the provided one with the package in 'Packages -> URP Volumetric Fog -> Textures -> Distortion'.")]
	public Texture3DParameter distortionTexture = new Texture3DParameter(null, true);
	[Tooltip("The size of distortion. Lower values mean higher frequency noise.")]
	public FloatParameter distortionScale = new FloatParameter(5.0f);
	[Tooltip("The intensity of distortion in each axii.")]
	public Vector3Parameter distortionIntensity = new Vector3Parameter(new Vector3(0.1f, -0.1f, 0.05f));
	[Tooltip("The velocity of distortion in each axii.")]
	public Vector3Parameter distortionVelocity = new Vector3Parameter(new Vector3(-0.02f, 0.01f, 0.015f));

	[Header("Misc. & Quality")]
	[Tooltip("The URP render pass event to render the volumetric fog.")]
	public VolumetricFogRenderPassEventParameter renderPassEvent = new VolumetricFogRenderPassEventParameter(VolumetricFogConstants.DefaultVolumetricFogRenderPassEvent);
	[Tooltip("Resolution multiplier to render the volumetric fog at. At 0.25, 1/16 of the pixels are rendered. At 0.5, 1/4 of the pixels are rendered.")]
	public ClampedFloatParameter resolution = new ClampedFloatParameter(0.5f, 0.25f, 0.5f);
	[Tooltip("The maximum raymarching steps per pixel. Greater values will increase the fog quality at the expense of performance.")]
	public ClampedIntParameter maximumSteps = new ClampedIntParameter(24, 4, 128);
	[Tooltip("This value is used to clamp and modify the maximum steps under certain circumstances. It helps to further tune down the maximum steps when there is no need for that many steps depending on the view. Lower values will decrease performance while enhancing quality.")]
	public ClampedFloatParameter minimumStepSize = new ClampedFloatParameter(0.25f, 0.2f, 2.0f);
	[Tooltip("The number of times that the fog texture will be blurred. Higher values lead to softer volumetric god rays at the cost of some performance.")]
	public ClampedIntParameter blurIterations = new ClampedIntParameter(2, 1, 6);
	[Tooltip("Reprojection uses information from previous frames to make the fog more stable, but can cause ghosting under certain circumstances. Unity's motion vectors are rendered when this option is enabled.")]
	public BoolParameter reprojection = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);
	[Tooltip("Disabling this will completely remove any feature from the volumetric fog from being rendered at all.")]
	public BoolParameter enabled = new BoolParameter(false, BoolParameter.DisplayType.Checkbox, true);

	#endregion

	#region Volume Component Methods

	private void OnValidate()
	{
		maximumHeight.value = Mathf.Max(baseHeight.value, maximumHeight.value);
		baseHeight.value = Mathf.Min(baseHeight.value, maximumHeight.value);

		noiseScale.value = Mathf.Max(0.0f, noiseScale.value);
		distortionScale.value = Mathf.Max(0.0f, distortionScale.value);

		SetNoise();
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

	#region Methods

	/// <summary>
	/// Sets the override state of the noise to match the mode selected and loads the textures when needed.
	/// </summary>
	private void SetNoise()
	{
#if UNITY_EDITOR
		if (noiseMode.value == VolumetricFogNoiseMode.Noise3DTexture || noiseMode.value == VolumetricFogNoiseMode.NoiseAndDistortion3DTextures)
		{
			if (noiseTexture.value == null)
			{
				noiseTexture.value = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture3D>("Packages/com.cqf.urpvolumetricfog/Textures/Noise_128x128x128_R32_SFloat.asset");
				noiseTexture.overrideState = true;
			}

			if (distortionTexture.value == null && noiseMode.value == VolumetricFogNoiseMode.NoiseAndDistortion3DTextures)
			{
				distortionTexture.value = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture3D>("Packages/com.cqf.urpvolumetricfog/Textures/Distortion_128x128x128_RGBA32_SFloat.asset");
				distortionTexture.overrideState = true;
			}
		}
		else
		{
			noiseTexture.value = null;
			distortionTexture.value = null;

			noiseTexture.overrideState = false;
			distortionTexture.overrideState = false;
		}
#endif
	}

	#endregion
}