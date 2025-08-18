using Unity.Collections;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

/// <summary>
/// The volumetric fog render pass.
/// </summary>
public sealed class VolumetricFogRenderPass : ScriptableRenderPass
{
	#region Definitions

	/// <summary>
	/// The subpasses the volumetric fog render pass is made of.
	/// </summary>
	private enum PassStage : byte
	{
		DownsampleDepth,
		VolumetricFogRender,
		VolumetricFogReprojection,
		VolumetricFogBlur,
		VolumetricFogUpsampleComposition
	}

	/// <summary>
	/// Structure to hold all the possible texture handles used by the pass.
	/// </summary>
	private struct TextureHandles
	{
		public TextureHandle downsampledCameraDepthTarget;
		public TextureHandle prevFrameDownsampledCameraDepthTarget;
		public TextureHandle volumetricFogRenderTarget;
		public TextureHandle volumetricFogHistoryTarget;
		public TextureHandle volumetricFogReprojectionTarget;
		public TextureHandle volumetricFogBlurRenderTarget;
		public TextureHandle volumetricFogUpsampleCompositionTarget;
	}

	/// <summary>
	/// Holds the data needed by the execution of the volumetric fog render pass subpasses.
	/// </summary>
	private class PassData
	{
		public PassStage stage;

		public TextureHandle source;
		public TextureHandle target;

		public Material material;
		public int materialPassIndex;
		public int materialAdditionalPassIndex;

		public TextureHandle downsampledCameraDepthTarget;
		public TextureHandle prevFrameDownsampledCameraDepthTarget;
		public TextureHandle volumetricFogRenderTarget;
		public TextureHandle volumetricFogHistoryTarget;
		public UniversalLightData lightData;
	}

	#endregion

	#region Private Attributes

	private const string DownsampledCameraDepthRTName = "_DownsampledCameraDepth";
	private const string PrevFrameDownsampledCameraDepthRTName = "_PrevFrameDownsampledCameraDepth";
	private const string VolumetricFogRenderRTName = "_VolumetricFog";
	private const string VolumetricFogHistoryRTName = "_VolumetricFogHistory";
	private const string VolumetricFogBlurRTName = "_VolumetricFogBlur";
	private const string VolumetricFogUpsampleCompositionRTName = "_VolumetricFogUpsampleComposition";

	private static readonly int DownsampledCameraDepthTextureId = Shader.PropertyToID("_DownsampledCameraDepthTexture");
	private static readonly int PrevFrameDownsampledCameraDepthTextureId = Shader.PropertyToID("_PrevFrameDownsampledCameraDepthTexture");
	private static readonly int VolumetricFogTextureId = Shader.PropertyToID("_VolumetricFogTexture");
	private static readonly int VolumetricFogHistoryTextureId = Shader.PropertyToID("_VolumetricFogHistoryTexture");

	private static readonly int FrameCountId = Shader.PropertyToID("_FrameCount");
	private static readonly int CustomAdditionalLightsCountId = Shader.PropertyToID("_CustomAdditionalLightsCount");
	private static readonly int DistanceId = Shader.PropertyToID("_Distance");
	private static readonly int BaseHeightId = Shader.PropertyToID("_BaseHeight");
	private static readonly int MaximumHeightId = Shader.PropertyToID("_MaximumHeight");
	private static readonly int GroundHeightId = Shader.PropertyToID("_GroundHeight");
	private static readonly int DensityId = Shader.PropertyToID("_Density");
	private static readonly int AbsortionId = Shader.PropertyToID("_Absortion");
	private static readonly int APVContributionWeigthId = Shader.PropertyToID("_APVContributionWeight");
	private static readonly int ReflectionProbesContributionWeightId = Shader.PropertyToID("_ReflectionProbesContributionWeight");
	private static readonly int TintId = Shader.PropertyToID("_Tint");
	private static readonly int NoiseTextureId = Shader.PropertyToID("_NoiseTexture");
	private static readonly int NoiseFrequencyId = Shader.PropertyToID("_NoiseFrequency");
	private static readonly int NoiseMinMaxId = Shader.PropertyToID("_NoiseMinMax");
	private static readonly int NoiseVelocityId = Shader.PropertyToID("_NoiseVelocity");
	private static readonly int MaxStepsId = Shader.PropertyToID("_MaxSteps");

	private static readonly int AnisotropiesArrayId = Shader.PropertyToID("_Anisotropies");
	private static readonly int ScatteringsArrayId = Shader.PropertyToID("_Scatterings");
	private static readonly int RadiiSqArrayId = Shader.PropertyToID("_RadiiSq");

	private static readonly float[] Anisotropies = new float[UniversalRenderPipeline.maxVisibleAdditionalLights + 1];
	private static readonly float[] Scatterings = new float[UniversalRenderPipeline.maxVisibleAdditionalLights + 1];
	private static readonly float[] RadiiSq = new float[UniversalRenderPipeline.maxVisibleAdditionalLights];

	private int downsampleDepthPassIndex;
	private int volumetricFogRenderPassIndex;
	private int volumetricFogReprojectionPassIndex;
	private int volumetricFogHorizontalBlurPassIndex;
	private int volumetricFogVerticalBlurPassIndex;
	private int volumetricFogUpsampleCompositionPassIndex;

	private Material downsampleDepthMaterial;
	private Material volumetricFogMaterial;

	private RTHandle volumetricFogHistoryRTHandle;
	private RTHandle prevFrameDownsampledCameraDepthRTHandle;

	private ProfilingSampler downsampleDepthProfilingSampler;

	#endregion

	#region Initialization Methods

	/// <summary>
	/// Constructor.
	/// </summary>
	/// <param name="downsampleDepthMaterial"></param>
	/// <param name="volumetricFogMaterial"></param>
	/// <param name="passEvent"></param>
	public VolumetricFogRenderPass(Material downsampleDepthMaterial, Material volumetricFogMaterial, RenderPassEvent passEvent) : base()
	{
		profilingSampler = new ProfilingSampler("Volumetric Fog");
		downsampleDepthProfilingSampler = new ProfilingSampler("Downsample Depth");
		renderPassEvent = passEvent;
		requiresIntermediateTexture = false;

		this.downsampleDepthMaterial = downsampleDepthMaterial;
		this.volumetricFogMaterial = volumetricFogMaterial;

		InitializePassesIndices();
	}

	/// <summary>
	/// Initializes the passes indices.
	/// </summary>
	private void InitializePassesIndices()
	{
		downsampleDepthPassIndex = downsampleDepthMaterial.FindPass("DownsampleDepth");
		volumetricFogRenderPassIndex = volumetricFogMaterial.FindPass("VolumetricFogRender");
		volumetricFogReprojectionPassIndex = volumetricFogMaterial.FindPass("VolumetricFogReprojection");
		volumetricFogHorizontalBlurPassIndex = volumetricFogMaterial.FindPass("VolumetricFogHorizontalBlur");
		volumetricFogVerticalBlurPassIndex = volumetricFogMaterial.FindPass("VolumetricFogVerticalBlur");
		volumetricFogUpsampleCompositionPassIndex = volumetricFogMaterial.FindPass("VolumetricFogUpsampleComposition");
	}

	#endregion

	#region Scriptable Render Pass Methods

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	/// <param name="renderGraph"></param>
	/// <param name="frameData"></param>
	public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
	{
		UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
		UniversalLightData lightData = frameData.Get<UniversalLightData>();
		UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

		bool reprojectionEnabled = true;

		TextureHandles texHandles = CreateRenderGraphTextures(renderGraph, cameraData, reprojectionEnabled);

		if (!reprojectionEnabled)
		{
			prevFrameDownsampledCameraDepthRTHandle?.Release();
			volumetricFogHistoryRTHandle?.Release();
		}

		using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass("Downsample Depth Pass", out PassData passData, downsampleDepthProfilingSampler))
		{
			passData.stage = PassStage.DownsampleDepth;
			passData.source = resourceData.cameraDepthTexture;
			passData.target = texHandles.downsampledCameraDepthTarget;
			passData.material = downsampleDepthMaterial;
			passData.materialPassIndex = downsampleDepthPassIndex;

			builder.SetRenderAttachment(texHandles.downsampledCameraDepthTarget, 0, AccessFlags.WriteAll);
			builder.UseTexture(resourceData.cameraDepthTexture);
			builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
		}

		using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass("Volumetric Fog Render Pass", out PassData passData, profilingSampler))
		{
			passData.stage = PassStage.VolumetricFogRender;
			passData.source = texHandles.downsampledCameraDepthTarget;
			passData.target = texHandles.volumetricFogRenderTarget;
			passData.material = volumetricFogMaterial;
			passData.materialPassIndex = volumetricFogRenderPassIndex;
			passData.downsampledCameraDepthTarget = texHandles.downsampledCameraDepthTarget;
			passData.lightData = lightData;

			builder.SetRenderAttachment(texHandles.volumetricFogRenderTarget, 0, AccessFlags.WriteAll);
			builder.UseTexture(texHandles.downsampledCameraDepthTarget);
			if (resourceData.mainShadowsTexture.IsValid())
				builder.UseTexture(resourceData.mainShadowsTexture);
			if (resourceData.additionalShadowsTexture.IsValid())
				builder.UseTexture(resourceData.additionalShadowsTexture);
			builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
		}

		if (reprojectionEnabled)
		{
			using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass("Volumetric Fog Reprojection Pass", out PassData passData, profilingSampler))
			{
				passData.stage = PassStage.VolumetricFogReprojection;
				passData.source = texHandles.volumetricFogRenderTarget;
				passData.target = texHandles.volumetricFogReprojectionTarget;
				passData.material = volumetricFogMaterial;
				passData.materialPassIndex = volumetricFogReprojectionPassIndex;
				passData.volumetricFogHistoryTarget = texHandles.volumetricFogHistoryTarget;
				passData.prevFrameDownsampledCameraDepthTarget = texHandles.prevFrameDownsampledCameraDepthTarget;

				builder.SetRenderAttachment(texHandles.volumetricFogReprojectionTarget, 0, AccessFlags.WriteAll);
				builder.UseTexture(texHandles.volumetricFogRenderTarget);
				builder.UseTexture(texHandles.volumetricFogHistoryTarget);
				builder.UseTexture(texHandles.downsampledCameraDepthTarget);
				builder.UseTexture(texHandles.prevFrameDownsampledCameraDepthTarget);
				if (resourceData.motionVectorColor.IsValid())
					builder.UseTexture(resourceData.motionVectorColor);
				if (resourceData.motionVectorDepth.IsValid())
					builder.UseTexture(resourceData.motionVectorDepth);
				builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
			}

			RenderGraphUtils.AddCopyPass(renderGraph, texHandles.downsampledCameraDepthTarget, texHandles.prevFrameDownsampledCameraDepthTarget, "Downsampled Depth Copy Pass");
			RenderGraphUtils.AddCopyPass(renderGraph, texHandles.volumetricFogReprojectionTarget, texHandles.volumetricFogHistoryTarget, "Volumetric Fog History Copy Pass");
		}

		TextureHandle lastFogRenderTarget = reprojectionEnabled ? texHandles.volumetricFogReprojectionTarget : texHandles.volumetricFogRenderTarget;

		using (IUnsafeRenderGraphBuilder builder = renderGraph.AddUnsafePass("Volumetric Fog Blur Pass", out PassData passData, profilingSampler))
		{
			passData.stage = PassStage.VolumetricFogBlur;
			passData.source = lastFogRenderTarget;
			passData.target = texHandles.volumetricFogBlurRenderTarget;
			passData.material = volumetricFogMaterial;
			passData.materialPassIndex = volumetricFogHorizontalBlurPassIndex;
			passData.materialAdditionalPassIndex = volumetricFogVerticalBlurPassIndex;

			builder.UseTexture(lastFogRenderTarget, AccessFlags.ReadWrite);
			builder.UseTexture(texHandles.volumetricFogBlurRenderTarget, AccessFlags.ReadWrite);
			builder.SetRenderFunc((PassData data, UnsafeGraphContext context) => ExecuteUnsafeBlurPass(data, context));
		}

		using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass("Volumetric Fog Upsample Composition Pass", out PassData passData, profilingSampler))
		{
			passData.stage = PassStage.VolumetricFogUpsampleComposition;
			passData.source = resourceData.cameraColor;
			passData.target = texHandles.volumetricFogUpsampleCompositionTarget;
			passData.material = volumetricFogMaterial;
			passData.materialPassIndex = volumetricFogUpsampleCompositionPassIndex;
			passData.volumetricFogRenderTarget = lastFogRenderTarget;

			builder.SetRenderAttachment(texHandles.volumetricFogUpsampleCompositionTarget, 0, AccessFlags.WriteAll);
			builder.UseTexture(resourceData.cameraDepthTexture);
			builder.UseTexture(texHandles.downsampledCameraDepthTarget);
			builder.UseTexture(lastFogRenderTarget);
			builder.UseTexture(resourceData.cameraColor);
			builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
		}

		resourceData.cameraColor = texHandles.volumetricFogUpsampleCompositionTarget;
	}

	#endregion

	#region Pass Execution Methods

	/// <summary>
	/// Executes the pass with the information from the pass data.
	/// </summary>
	/// <param name="passData"></param>
	/// <param name="context"></param>
	private static void ExecutePass(PassData passData, RasterGraphContext context)
	{
		PassStage stage = passData.stage;

		if (stage == PassStage.VolumetricFogRender)
		{
			passData.material.SetTexture(DownsampledCameraDepthTextureId, passData.downsampledCameraDepthTarget);
			UpdateVolumetricFogMaterialParameters(passData.material, passData.lightData.mainLightIndex, passData.lightData.additionalLightsCount, passData.lightData.visibleLights);
		}
		else if (stage == PassStage.VolumetricFogReprojection)
		{
			passData.material.SetTexture(VolumetricFogHistoryTextureId, passData.volumetricFogHistoryTarget);
			passData.material.SetTexture(PrevFrameDownsampledCameraDepthTextureId, passData.prevFrameDownsampledCameraDepthTarget);
		}
		else if (stage == PassStage.VolumetricFogUpsampleComposition)
		{
			passData.material.SetTexture(VolumetricFogTextureId, passData.volumetricFogRenderTarget);
		}

		Blitter.BlitTexture(context.cmd, passData.source, Vector2.one, passData.material, passData.materialPassIndex);
	}

	/// <summary>
	/// Executes the unsafe pass that does up to multiple separable blurs to the volumetric fog.
	/// </summary>
	/// <param name="passData"></param>
	/// <param name="context"></param>
	private static void ExecuteUnsafeBlurPass(PassData passData, UnsafeGraphContext context)
	{
		CommandBuffer unsafeCmd = CommandBufferHelpers.GetNativeCommandBuffer(context.cmd);

		int blurIterations = GetVolumetricFogVolumeComponent().blurIterations.value;

		for (int i = 0; i < blurIterations; ++i)
		{
			Blitter.BlitCameraTexture(unsafeCmd, passData.source, passData.target, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, passData.material, passData.materialPassIndex);
			Blitter.BlitCameraTexture(unsafeCmd, passData.target, passData.source, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, passData.material, passData.materialAdditionalPassIndex);
		}
	}

	#endregion

	#region Material Parameters Methods

	/// <summary>
	/// Updates the volumetric fog material parameters.
	/// </summary>
	/// <param name="volumetricFogMaterial"></param>
	/// <param name="mainLightIndex"></param>
	/// <param name="additionalLightsCount"></param>
	/// <param name="visibleLights"></param>
	private static void UpdateVolumetricFogMaterialParameters(Material volumetricFogMaterial, int mainLightIndex, int additionalLightsCount, NativeArray<VisibleLight> visibleLights)
	{
		VolumetricFogVolumeComponent fogVolume = GetVolumetricFogVolumeComponent();

		bool enableGround = fogVolume.enableGround.overrideState && fogVolume.enableGround.value;
		bool enableAPVContribution = fogVolume.enableAPVContribution.value && fogVolume.APVContributionWeight.value > 0.0f;
		bool enableReflectionProbesContribution = fogVolume.enableReflectionProbesContribution.value && fogVolume.reflectionProbesContributionWeight.value > 0.0f;
		bool enableMainLightContribution = fogVolume.enableMainLightContribution.value && fogVolume.scattering.value > 0.0f && mainLightIndex > -1;
		bool enableAdditionalLightsContribution = fogVolume.enableAdditionalLightsContribution.value && additionalLightsCount > 0;
		bool enableNoise = fogVolume.enableNoise.value && fogVolume.noiseTexture.value != null && fogVolume.noiseScale.value > 0.0f;

		if (enableAPVContribution)
			volumetricFogMaterial.EnableKeyword("_APV_CONTRIBUTION");
		else
			volumetricFogMaterial.DisableKeyword("_APV_CONTRIBUTION");

		if (enableReflectionProbesContribution)
			volumetricFogMaterial.EnableKeyword("_REFLECTION_PROBES_CONTRIBUTION");
		else
			volumetricFogMaterial.DisableKeyword("_REFLECTION_PROBES_CONTRIBUTION");

		if (enableMainLightContribution)
			volumetricFogMaterial.EnableKeyword("_MAIN_LIGHT_CONTRIBUTION");
		else
			volumetricFogMaterial.DisableKeyword("_MAIN_LIGHT_CONTRIBUTION");

		if (enableAdditionalLightsContribution)
			volumetricFogMaterial.EnableKeyword("_ADDITIONAL_LIGHTS_CONTRIBUTION");
		else
			volumetricFogMaterial.DisableKeyword("_ADDITIONAL_LIGHTS_CONTRIBUTION");

		if (enableNoise)
			volumetricFogMaterial.EnableKeyword("_NOISE");
		else
			volumetricFogMaterial.DisableKeyword("_NOISE");

		UpdateLightsParameters(volumetricFogMaterial, fogVolume, enableMainLightContribution, enableAdditionalLightsContribution, mainLightIndex, visibleLights);

		volumetricFogMaterial.SetInteger(FrameCountId, Time.renderedFrameCount % 64);
		volumetricFogMaterial.SetInteger(CustomAdditionalLightsCountId, additionalLightsCount);
		volumetricFogMaterial.SetFloat(DistanceId, fogVolume.distance.value);
		volumetricFogMaterial.SetFloat(BaseHeightId, fogVolume.baseHeight.value);
		volumetricFogMaterial.SetFloat(MaximumHeightId, fogVolume.maximumHeight.value);
		volumetricFogMaterial.SetFloat(GroundHeightId, enableGround ? fogVolume.groundHeight.value : float.MinValue);
		volumetricFogMaterial.SetFloat(DensityId, fogVolume.density.value);
		volumetricFogMaterial.SetFloat(AbsortionId, 1.0f / fogVolume.attenuationDistance.value);
		volumetricFogMaterial.SetFloat(APVContributionWeigthId, enableAPVContribution ? fogVolume.APVContributionWeight.value : 0.0f);
		volumetricFogMaterial.SetFloat(ReflectionProbesContributionWeightId, enableReflectionProbesContribution ? fogVolume.reflectionProbesContributionWeight.value : 0.0f);
		volumetricFogMaterial.SetColor(TintId, fogVolume.tint.value);
		volumetricFogMaterial.SetTexture(NoiseTextureId, enableNoise ? fogVolume.noiseTexture.value : null);
		volumetricFogMaterial.SetFloat(NoiseFrequencyId, enableNoise ? (1.0f / fogVolume.noiseScale.value) : float.MaxValue);
		volumetricFogMaterial.SetVector(NoiseMinMaxId, enableNoise ? new Vector2(fogVolume.noiseMinMax.value.x, fogVolume.noiseMinMax.value.y) : Vector2.zero);
		volumetricFogMaterial.SetVector(NoiseVelocityId, enableNoise ? fogVolume.noiseVelocity.value : Vector3.zero);
		volumetricFogMaterial.SetInteger(MaxStepsId, fogVolume.maxSteps.value);
	}

	/// <summary>
	/// Updates the lights parameters from the material.
	/// </summary>
	/// <param name="volumetricFogMaterial"></param>
	/// <param name="fogVolume"></param>
	/// <param name="enableMainLightContribution"></param>
	/// <param name="enableAdditionalLightsContribution"></param>
	/// <param name="mainLightIndex"></param>
	/// <param name="visibleLights"></param>
	private static void UpdateLightsParameters(Material volumetricFogMaterial, VolumetricFogVolumeComponent fogVolume, bool enableMainLightContribution, bool enableAdditionalLightsContribution, int mainLightIndex, NativeArray<VisibleLight> visibleLights)
	{
		if (enableMainLightContribution)
		{
			Anisotropies[visibleLights.Length - 1] = fogVolume.anisotropy.value;
			Scatterings[visibleLights.Length - 1] = fogVolume.scattering.value;
		}

		if (enableAdditionalLightsContribution)
		{
			int additionalLightIndex = 0;

			for (int i = 0; i < visibleLights.Length; ++i)
			{
				if (i == mainLightIndex)
					continue;

				float anisotropy = 0.0f;
				float scattering = 0.0f;
				float radius = 0.0f;

				if (visibleLights[i].light.TryGetComponent(out VolumetricAdditionalLight volumetricLight))
				{
					if (volumetricLight.gameObject.activeInHierarchy && volumetricLight.enabled)
					{
						anisotropy = volumetricLight.Anisotropy;
						scattering = volumetricLight.Scattering;
						radius = volumetricLight.Radius;
					}
				}

				Anisotropies[additionalLightIndex] = anisotropy;
				Scatterings[additionalLightIndex] = scattering;
				RadiiSq[additionalLightIndex++] = radius * radius;
			}
		}

		if (enableMainLightContribution || enableAdditionalLightsContribution)
		{
			volumetricFogMaterial.SetFloatArray(AnisotropiesArrayId, Anisotropies);
			volumetricFogMaterial.SetFloatArray(ScatteringsArrayId, Scatterings);
			volumetricFogMaterial.SetFloatArray(RadiiSqArrayId, RadiiSq);
		}
	}

	#endregion

	#region Methods

	/// <summary>
	/// Configures the volumetric fog render pass for the tick, before adding the pass to the renderer.
	/// </summary>
	public void ConfigurePassForTick()
	{
		renderPassEvent = (RenderPassEvent)GetVolumetricFogVolumeComponent().renderPassEvent.value;
		ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Motion);
	}

	/// <summary>
	/// Disposes the resources used by this pass.
	/// </summary>
	public void Dispose()
	{
		volumetricFogHistoryRTHandle?.Release();
		prevFrameDownsampledCameraDepthRTHandle?.Release();
	}

	/// <summary>
	/// Creates and returns all the necessary render graph textures.
	/// </summary>
	/// <param name="renderGraph"></param>
	/// <param name="cameraData"></param>
	/// <param name="reprojectionEnabled"></param>
	/// <returns></returns>
	private TextureHandles CreateRenderGraphTextures(RenderGraph renderGraph, UniversalCameraData cameraData, bool reprojectionEnabled)
	{
		// TODO: This pattern should not be used https://discussions.unity.com/t/introduction-of-render-graph-in-the-universal-render-pipeline-urp/930355/602
		RenderTextureDescriptor cameraTargetDescriptor = cameraData.cameraTargetDescriptor;
		cameraTargetDescriptor.depthBufferBits = (int)DepthBits.None;

		RenderTextureFormat originalColorFormat = cameraTargetDescriptor.colorFormat;
		Vector2Int originalResolution = new Vector2Int(cameraTargetDescriptor.width, cameraTargetDescriptor.height);

		int downsampleFactor = (int)GetVolumetricFogVolumeComponent().resolution.value;

		cameraTargetDescriptor.width /= downsampleFactor;
		cameraTargetDescriptor.height /= downsampleFactor;
		cameraTargetDescriptor.graphicsFormat = GraphicsFormat.R32_SFloat;
		TextureHandles texHandles = new TextureHandles();
		texHandles.downsampledCameraDepthTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, DownsampledCameraDepthRTName, false);
		if (reprojectionEnabled)
		{
			RenderingUtils.ReAllocateHandleIfNeeded(ref prevFrameDownsampledCameraDepthRTHandle, cameraTargetDescriptor, wrapMode: TextureWrapMode.Clamp, name: PrevFrameDownsampledCameraDepthRTName);
			texHandles.prevFrameDownsampledCameraDepthTarget = renderGraph.ImportTexture(prevFrameDownsampledCameraDepthRTHandle);
		}

		cameraTargetDescriptor.colorFormat = RenderTextureFormat.ARGBHalf;
		texHandles.volumetricFogRenderTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, VolumetricFogRenderRTName, false);
		if (reprojectionEnabled)
		{
			RenderingUtils.ReAllocateHandleIfNeeded(ref volumetricFogHistoryRTHandle, cameraTargetDescriptor, wrapMode: TextureWrapMode.Clamp, name: VolumetricFogHistoryRTName);
			texHandles.volumetricFogHistoryTarget = renderGraph.ImportTexture(volumetricFogHistoryRTHandle);
			texHandles.volumetricFogReprojectionTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, "", false);
		}
		texHandles.volumetricFogBlurRenderTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, VolumetricFogBlurRTName, false);

		cameraTargetDescriptor.width = originalResolution.x;
		cameraTargetDescriptor.height = originalResolution.y;
		cameraTargetDescriptor.colorFormat = originalColorFormat;
		texHandles.volumetricFogUpsampleCompositionTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, VolumetricFogUpsampleCompositionRTName, false);

		return texHandles;
	}

	/// <summary>
	/// Gets the volume component for the volumetric fog.
	/// </summary>
	/// <returns></returns>
	private static VolumetricFogVolumeComponent GetVolumetricFogVolumeComponent()
	{
		return VolumeManager.instance.stack.GetComponent<VolumetricFogVolumeComponent>();
	}

	#endregion
}