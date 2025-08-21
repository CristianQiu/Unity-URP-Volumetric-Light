using UnityEditor;
using UnityEditor.Rendering;

/// <summary>
/// Custom editor for the volumetric fog volume component.
/// </summary>
[CustomEditor(typeof(VolumetricFogVolumeComponent))]
public sealed class VolumetricFogVolumeComponentEditor : VolumeComponentEditor
{
	#region Private Attributes

	private SerializedDataParameter distance;
	private SerializedDataParameter baseHeight;
	private SerializedDataParameter maximumHeight;
	private SerializedDataParameter groundHeight;

	private SerializedDataParameter density;
	private SerializedDataParameter attenuationDistance;
	private SerializedDataParameter mainLightContribution;
	private SerializedDataParameter mainLightAnisotropy;
	private SerializedDataParameter mainLightScattering;
	private SerializedDataParameter mainLightTint;
	private SerializedDataParameter additionalLightsContribution;
	private SerializedDataParameter enableAPVContribution;
	private SerializedDataParameter APVContributionWeight;
	private SerializedDataParameter enableReflectionProbesContribution;
	private SerializedDataParameter reflectionProbesContributionWeight;

	private SerializedDataParameter noiseMode;
	private SerializedDataParameter noiseTexture;
	private SerializedDataParameter noiseScale;
	private SerializedDataParameter noiseMinMax;
	private SerializedDataParameter noiseVelocity;
	private SerializedDataParameter distortionTexture;
	private SerializedDataParameter distortionScale;
	private SerializedDataParameter distortionIntensity;
	private SerializedDataParameter distortionVelocity;

	private SerializedDataParameter renderPassEvent;
	private SerializedDataParameter resolution;
	private SerializedDataParameter maximumSteps;
	private SerializedDataParameter minimumStepSize;
	private SerializedDataParameter blurIterations;
	private SerializedDataParameter reprojection;
	private SerializedDataParameter enabled;

	#endregion

	#region VolumeComponentEditor Methods

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	public override void OnEnable()
	{
		PropertyFetcher<VolumetricFogVolumeComponent> pf = new PropertyFetcher<VolumetricFogVolumeComponent>(serializedObject);

		distance = Unpack(pf.Find(x => x.distance));
		baseHeight = Unpack(pf.Find(x => x.baseHeight));
		maximumHeight = Unpack(pf.Find(x => x.maximumHeight));
		groundHeight = Unpack(pf.Find(x => x.groundHeight));

		density = Unpack(pf.Find(x => x.density));
		attenuationDistance = Unpack(pf.Find(x => x.attenuationDistance));
		mainLightContribution = Unpack(pf.Find(x => x.mainLightContribution));
		mainLightAnisotropy = Unpack(pf.Find(x => x.mainLightAnisotropy));
		mainLightScattering = Unpack(pf.Find(x => x.mainLightScattering));
		mainLightTint = Unpack(pf.Find(x => x.mainLightTint));
		additionalLightsContribution = Unpack(pf.Find(x => x.additionalLightsContribution));
		enableAPVContribution = Unpack(pf.Find(x => x.APVContribution));
		APVContributionWeight = Unpack(pf.Find(x => x.APVContributionWeight));
		enableReflectionProbesContribution = Unpack(pf.Find(x => x.reflectionProbesContribution));
		reflectionProbesContributionWeight = Unpack(pf.Find(x => x.reflectionProbesContributionWeight));

		noiseMode = Unpack(pf.Find(x => x.noiseMode));
		noiseTexture = Unpack(pf.Find(x => x.noiseTexture));
		noiseScale = Unpack(pf.Find(x => x.noiseScale));
		noiseMinMax = Unpack(pf.Find(x => x.noiseMinMax));
		noiseVelocity = Unpack(pf.Find(x => x.noiseVelocity));
		distortionTexture = Unpack(pf.Find(x => x.distortionTexture));
		distortionScale = Unpack(pf.Find(x => x.distortionScale));
		distortionIntensity = Unpack(pf.Find(x => x.distortionIntensity));
		distortionVelocity = Unpack(pf.Find(x => x.distortionVelocity));

		renderPassEvent = Unpack(pf.Find(x => x.renderPassEvent));
		resolution = Unpack(pf.Find(x => x.resolution));
		maximumSteps = Unpack(pf.Find(x => x.maximumSteps));
		minimumStepSize = Unpack(pf.Find(x => x.minimumStepSize));
		blurIterations = Unpack(pf.Find(x => x.blurIterations));
		reprojection = Unpack(pf.Find(x => x.reprojection));
		enabled = Unpack(pf.Find(x => x.enabled));
	}

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	public override void OnInspectorGUI()
	{
		bool isEnabled = enabled.overrideState.boolValue && enabled.value.boolValue;

		if (!isEnabled)
		{
			PropertyField(enabled);
			return;
		}

		bool enabledMainLightContribution = mainLightContribution.overrideState.boolValue && mainLightContribution.value.boolValue;
		bool enabledAPVContribution = enableAPVContribution.overrideState.boolValue && enableAPVContribution.value.boolValue;
		bool enabledReflectionProbesContribution = enableReflectionProbesContribution.overrideState.boolValue && enableReflectionProbesContribution.value.boolValue;
		bool enabledNoise = noiseMode.overrideState.boolValue && noiseMode.value.enumValueIndex == (int)VolumetricFogNoiseMode.Noise3DTexture;
		bool enabledDistortion = noiseMode.overrideState.boolValue && noiseMode.value.enumValueIndex == (int)VolumetricFogNoiseMode.NoiseAndDistortion3DTextures;

		PropertyField(distance);
		PropertyField(baseHeight);
		PropertyField(maximumHeight);
		PropertyField(groundHeight);

		PropertyField(density);
		PropertyField(attenuationDistance);
		PropertyField(mainLightContribution);
		if (enabledMainLightContribution)
		{
			PropertyField(mainLightAnisotropy);
			PropertyField(mainLightScattering);
			PropertyField(mainLightTint);
		}
		PropertyField(additionalLightsContribution);
		PropertyField(enableAPVContribution);
		if (enabledAPVContribution)
			PropertyField(APVContributionWeight);
		PropertyField(enableReflectionProbesContribution);
		if (enabledReflectionProbesContribution)
			PropertyField(reflectionProbesContributionWeight);

		PropertyField(noiseMode);
		if (enabledNoise || enabledDistortion)
		{
			PropertyField(noiseTexture);
			PropertyField(noiseScale);
			PropertyField(noiseMinMax);
			PropertyField(noiseVelocity);
		}
		if (enabledDistortion)
		{
			PropertyField(distortionTexture);
			PropertyField(distortionScale);
			PropertyField(distortionIntensity);
			PropertyField(distortionVelocity);
		}

		PropertyField(renderPassEvent);
		PropertyField(resolution);
		PropertyField(maximumSteps);
		PropertyField(minimumStepSize);
		PropertyField(blurIterations);
		PropertyField(reprojection);
		PropertyField(enabled);
	}

	#endregion
}