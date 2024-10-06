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
	private SerializedDataParameter tint;

	private SerializedDataParameter enableMainLightContribution;
	private SerializedDataParameter mainLightAnisotropy;
	private SerializedDataParameter mainLightScattering;

	private SerializedDataParameter enableAdditionalLightsContribution;
	private SerializedDataParameter additionalLightsAnisotropy;
	private SerializedDataParameter additionalLightsScattering;
	private SerializedDataParameter additionalLightsRadius;

	private SerializedDataParameter maxSteps;
	private SerializedDataParameter blurIterations;
	private SerializedDataParameter enabled;

	#endregion

	#region VolumeComponentEditor Methods

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	public override void OnEnable()
	{
		PropertyFetcher<VolumetricFogVolumeComponent> p = new PropertyFetcher<VolumetricFogVolumeComponent>(serializedObject);

		distance = Unpack(p.Find(x => x.distance));
		baseHeight = Unpack(p.Find(x => x.baseHeight));
		maximumHeight = Unpack(p.Find(x => x.maximumHeight));

		enableGround = Unpack(p.Find(x => x.enableGround));
		groundHeight = Unpack(p.Find(x => x.groundHeight));

		density = Unpack(p.Find(x => x.density));
		attenuationDistance = Unpack(p.Find(x => x.attenuationDistance));
		tint = Unpack(p.Find(x => x.mainLightColorTint));

		enableMainLightContribution = Unpack(p.Find(x => x.enableMainLightContribution));
		mainLightAnisotropy = Unpack(p.Find(x => x.mainLightAnisotropy));
		mainLightScattering = Unpack(p.Find(x => x.mainLightScattering));

		enableAdditionalLightsContribution = Unpack(p.Find(x => x.enableAdditionalLightsContribution));
		additionalLightsAnisotropy = Unpack(p.Find(x => x.additionalLightsAnisotropy));
		additionalLightsScattering = Unpack(p.Find(x => x.additionalLightsScattering));
		additionalLightsRadius = Unpack(p.Find(x => x.additionalLightsRadius));

		maxSteps = Unpack(p.Find(x => x.maxSteps));
		blurIterations = Unpack(p.Find(x => x.blurIterations));
		enabled = Unpack(p.Find(x => x.enabled));
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
		}
		else
		{
			bool enabledMainLightContribution = enableMainLightContribution.overrideState.boolValue && enableMainLightContribution.value.boolValue;
			bool enabledAdditionalLightsContribution = enableAdditionalLightsContribution.overrideState.boolValue && enableAdditionalLightsContribution.value.boolValue;

			PropertyField(distance);
			PropertyField(baseHeight);
			PropertyField(maximumHeight);

			PropertyField(enableGround);
			if (enableGround.overrideState.boolValue && enableGround.value.boolValue)
				PropertyField(groundHeight);

			PropertyField(density);
			PropertyField(attenuationDistance);

			PropertyField(enableMainLightContribution);
			if (enabledMainLightContribution)
			{
				PropertyField(mainLightAnisotropy);
				PropertyField(mainLightScattering);
				PropertyField(tint);
			}

			PropertyField(enableAdditionalLightsContribution);
			if (enabledAdditionalLightsContribution)
			{
				PropertyField(additionalLightsAnisotropy);
				PropertyField(additionalLightsScattering);
				PropertyField(additionalLightsRadius);
			}

			PropertyField(maxSteps);
			PropertyField(blurIterations);
			PropertyField(enabled);
		}
	}

	#endregion
}