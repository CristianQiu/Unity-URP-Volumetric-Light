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
	private SerializedDataParameter enableGround;
	private SerializedDataParameter groundHeight;

	private SerializedDataParameter density;
	private SerializedDataParameter attenuationDistance;
	private SerializedDataParameter enableAPVContribution;
	private SerializedDataParameter APVContributionWeight;
	private SerializedDataParameter enableReflectionProbesContribution;
	private SerializedDataParameter reflectionProbesContributionWeight;

	private SerializedDataParameter enableMainLightContribution;
	private SerializedDataParameter anisotropy;
	private SerializedDataParameter scattering;
	private SerializedDataParameter tint;

	private SerializedDataParameter enableAdditionalLightsContribution;

	private SerializedDataParameter enableNoise;
	private SerializedDataParameter noiseTexture;
	private SerializedDataParameter noiseScale;
	private SerializedDataParameter noiseMinMax;
	private SerializedDataParameter noiseVelocity;

	private SerializedDataParameter resolution;
	private SerializedDataParameter maxSteps;
	private SerializedDataParameter blurIterations;
	private SerializedDataParameter enabled;

	private SerializedDataParameter renderPassEvent;

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
		enableGround = Unpack(pf.Find(x => x.enableGround));
		groundHeight = Unpack(pf.Find(x => x.groundHeight));

		density = Unpack(pf.Find(x => x.density));
		attenuationDistance = Unpack(pf.Find(x => x.attenuationDistance));
		enableAPVContribution = Unpack(pf.Find(x => x.enableAPVContribution));
		APVContributionWeight = Unpack(pf.Find(x => x.APVContributionWeight));
		enableReflectionProbesContribution = Unpack(pf.Find(x => x.enableReflectionProbesContribution));
		reflectionProbesContributionWeight = Unpack(pf.Find(x => x.reflectionProbesContributionWeight));

		enableMainLightContribution = Unpack(pf.Find(x => x.enableMainLightContribution));
		anisotropy = Unpack(pf.Find(x => x.anisotropy));
		scattering = Unpack(pf.Find(x => x.scattering));
		tint = Unpack(pf.Find(x => x.tint));

		enableAdditionalLightsContribution = Unpack(pf.Find(x => x.enableAdditionalLightsContribution));

		enableNoise = Unpack(pf.Find(x => x.enableNoise));
		noiseTexture = Unpack(pf.Find(x => x.noiseTexture));
		noiseScale = Unpack(pf.Find(x => x.noiseScale));
		noiseMinMax = Unpack(pf.Find(x => x.noiseMinMax));
		noiseVelocity = Unpack(pf.Find(x => x.noiseVelocity));

		resolution = Unpack(pf.Find(x => x.resolution));
		maxSteps = Unpack(pf.Find(x => x.maxSteps));
		blurIterations = Unpack(pf.Find(x => x.blurIterations));
		enabled = Unpack(pf.Find(x => x.enabled));

		renderPassEvent = Unpack(pf.Find(x => x.renderPassEvent));
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

		bool enabledGround = enableGround.overrideState.boolValue && enableGround.value.boolValue;
		bool enabledAPVContribution = enableAPVContribution.overrideState.boolValue && enableAPVContribution.value.boolValue;
		bool enabledReflectionProbesContribution = enableReflectionProbesContribution.overrideState.boolValue && enableReflectionProbesContribution.value.boolValue;
		bool enabledNoise = enableNoise.overrideState.boolValue && enableNoise.value.boolValue;
		bool enabledMainLightContribution = enableMainLightContribution.overrideState.boolValue && enableMainLightContribution.value.boolValue;

		PropertyField(distance);
		PropertyField(baseHeight);
		PropertyField(maximumHeight);
		PropertyField(enableGround);
		if (enabledGround)
			PropertyField(groundHeight);

		PropertyField(density);
		PropertyField(attenuationDistance);
		PropertyField(enableAPVContribution);
		if (enabledAPVContribution)
			PropertyField(APVContributionWeight);
		PropertyField(enableReflectionProbesContribution);
		if (enabledReflectionProbesContribution)
			PropertyField(reflectionProbesContributionWeight);

		PropertyField(enableMainLightContribution);
		if (enabledMainLightContribution)
		{
			PropertyField(anisotropy);
			PropertyField(scattering);
			PropertyField(tint);
		}

		PropertyField(enableAdditionalLightsContribution);

		PropertyField(enableNoise);
		if (enabledNoise)
		{
			PropertyField(noiseTexture);
			PropertyField(noiseScale);
			PropertyField(noiseMinMax);
			PropertyField(noiseVelocity);
		}

		PropertyField(resolution);
		PropertyField(maxSteps);
		PropertyField(blurIterations);
		PropertyField(enabled);

		PropertyField(renderPassEvent);
	}

	#endregion
}