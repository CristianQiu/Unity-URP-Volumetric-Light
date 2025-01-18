using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Unity.Collections;

#if UNITY_6000_0_OR_NEWER
using System;
using UnityEngine.Rendering.RenderGraphModule;
#endif

/// <summary>
/// The volumetric fog render pass.
/// </summary>
public sealed class VolumetricFogRenderPass : ScriptableRenderPass
{
	#region Definitions

#if UNITY_6000_0_OR_NEWER

	/// <summary>
	/// The subpasses the volumetric fog render pass is made of.
	/// </summary>
	private enum PassStage : byte
	{
		DownsampleDepth,
		VolumetricFogRender,
		Blur,
		UpsampleComposition
	}

	/// <summary>
	/// Holds the data needed by the execution of the volumetric fog render pass subpasses.
	/// </summary>
	private class PassData
	{
		public PassStage stage;

		public TextureHandle target;
		public TextureHandle source;

		public Material material;
		public int materialPassIndex;
		public int materialAdditionalPassIndex;

		public UniversalLightData lightData;
		public TextureHandle halfResCameraDepthTarget;
		public TextureHandle volumetricFogTarget;

		public bool orthographic;
	}

#endif

	#endregion

	#region Private Attributes

	private const string HalfResCameraDepthRTName = "_HalfResCameraDepth";
	private const string VolumetricFogRenderRTName = "_VolumetricFog";
	private const string VolumetricFogBlurRTName = "_VolumetricFogBlur";
	private const string VolumetricFogUpsampleCompositionRTName = "_VolumetricFogUpsampleComposition";

	private static readonly float[] Anisotropies = new float[UniversalRenderPipeline.maxVisibleAdditionalLights + 1];
	private static readonly float[] Scatterings = new float[UniversalRenderPipeline.maxVisibleAdditionalLights + 1];
	private static readonly float[] RadiiSq = new float[UniversalRenderPipeline.maxVisibleAdditionalLights];

	private static readonly int AnisotropiesArrayId = Shader.PropertyToID("_Anisotropies");
	private static readonly int ScatteringsArrayId = Shader.PropertyToID("_Scatterings");
	private static readonly int RadiiSqArrayId = Shader.PropertyToID("_RadiiSq");

	private static readonly int FrameCountId = Shader.PropertyToID("_FrameCount");
	private static readonly int CustomAdditionalLightsCountId = Shader.PropertyToID("_CustomAdditionalLightsCount");
	private static readonly int DistanceId = Shader.PropertyToID("_Distance");
	private static readonly int BaseHeightId = Shader.PropertyToID("_BaseHeight");
	private static readonly int MaximumHeightId = Shader.PropertyToID("_MaximumHeight");
	private static readonly int GroundHeightId = Shader.PropertyToID("_GroundHeight");
	private static readonly int DensityId = Shader.PropertyToID("_Density");
	private static readonly int AbsortionId = Shader.PropertyToID("_Absortion");
	private static readonly int TintId = Shader.PropertyToID("_Tint");
	private static readonly int MaxStepsId = Shader.PropertyToID("_MaxSteps");

	private static readonly int HalfResCameraDepthTextureId = Shader.PropertyToID("_HalfResCameraDepthTexture");
	private static readonly int VolumetricFogTextureId = Shader.PropertyToID("_VolumetricFogTexture");

	private int downsampleDepthPassIndex;
	private int volumetricFogRenderPassIndex;
	private int volumetricFogHorizontalBlurPassIndex;
	private int volumetricFogVerticalBlurPassIndex;
	private int volumetricFogUpsampleCompositionPassIndex;

	private Material downsampleDepthMaterial;
	private Material volumetricFogMaterial;

	private RTHandle halfResCameraDepthRTHandle;
	private RTHandle volumetricFogRenderRTHandle;
	private RTHandle volumetricFogBlurRTHandle;
	private RTHandle volumetricFogUpsampleCompositionRTHandle;

	private ProfilingSampler downsampleDepthProfilingSampler;

	#endregion

	#region Initialization Methods

	public VolumetricFogRenderPass(Material downsampleDepthMaterial, Material volumetricFogMaterial) : base()
	{
		// Use BeforeRenderingPostprocessing instead of AfterRenderingTransparents. It works better
		// with motion blur. BeforeRenderingTransparents is also an option depending on the needs.
		profilingSampler = new ProfilingSampler("Volumetric Fog");
		downsampleDepthProfilingSampler = new ProfilingSampler("Downsample Depth");
		renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
#if UNITY_6000_0_OR_NEWER
		requiresIntermediateTexture = false;
#endif

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
		volumetricFogHorizontalBlurPassIndex = volumetricFogMaterial.FindPass("HorizontalBlur");
		volumetricFogVerticalBlurPassIndex = volumetricFogMaterial.FindPass("VerticalBlur");
		volumetricFogUpsampleCompositionPassIndex = volumetricFogMaterial.FindPass("UpsampleComposition");
	}

	#endregion

	#region Scriptable Render Pass Methods

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	/// <param name="cmd"></param>
	/// <param name="renderingData"></param>
#if UNITY_6000_0_OR_NEWER
	[Obsolete]
#endif
	public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
	{
		base.OnCameraSetup(cmd, ref renderingData);

		RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
		cameraTargetDescriptor.depthBufferBits = (int)DepthBits.None;

		RenderTextureFormat originalColorFormat = cameraTargetDescriptor.colorFormat;
		Vector2Int originalResolution = new Vector2Int(cameraTargetDescriptor.width, cameraTargetDescriptor.height);

		cameraTargetDescriptor.width /= 2;
		cameraTargetDescriptor.height /= 2;
		cameraTargetDescriptor.graphicsFormat = GraphicsFormat.R32_SFloat;
		RenderingUtils.ReAllocateIfNeeded(ref halfResCameraDepthRTHandle, cameraTargetDescriptor, wrapMode: TextureWrapMode.Clamp, name: HalfResCameraDepthRTName);

		cameraTargetDescriptor.colorFormat = RenderTextureFormat.ARGBHalf;
		RenderingUtils.ReAllocateIfNeeded(ref volumetricFogRenderRTHandle, cameraTargetDescriptor, wrapMode: TextureWrapMode.Clamp, name: VolumetricFogRenderRTName);
		RenderingUtils.ReAllocateIfNeeded(ref volumetricFogBlurRTHandle, cameraTargetDescriptor, wrapMode: TextureWrapMode.Clamp, name: VolumetricFogBlurRTName);

		cameraTargetDescriptor.width = originalResolution.x;
		cameraTargetDescriptor.height = originalResolution.y;
		cameraTargetDescriptor.colorFormat = originalColorFormat;
		RenderingUtils.ReAllocateIfNeeded(ref volumetricFogUpsampleCompositionRTHandle, cameraTargetDescriptor, wrapMode: TextureWrapMode.Clamp, name: VolumetricFogUpsampleCompositionRTName);
	}

	/// <summary>
	/// <inheritdoc/>
	/// </summary>
	/// <param name="context"></param>
	/// <param name="renderingData"></param>
#if UNITY_6000_0_OR_NEWER
	[Obsolete]
#endif
	public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
	{
		CommandBuffer cmd = CommandBufferPool.Get();

		using (new ProfilingScope(cmd, downsampleDepthProfilingSampler))
		{
			Blitter.BlitCameraTexture(cmd, halfResCameraDepthRTHandle, halfResCameraDepthRTHandle, downsampleDepthMaterial, downsampleDepthPassIndex);
			volumetricFogMaterial.SetTexture(HalfResCameraDepthTextureId, halfResCameraDepthRTHandle);
		}

		using (new ProfilingScope(cmd, profilingSampler))
		{
			UpdateVolumetricFogMaterialProperties(volumetricFogMaterial, renderingData.lightData.visibleLights, renderingData.lightData.mainLightIndex, renderingData.lightData.additionalLightsCount);
			Blitter.BlitCameraTexture(cmd, volumetricFogRenderRTHandle, volumetricFogRenderRTHandle, volumetricFogMaterial, volumetricFogRenderPassIndex);

			int blurIterations = VolumeManager.instance.stack.GetComponent<VolumetricFogVolumeComponent>().blurIterations.value;
			
			for (int i = 0; i < blurIterations; ++i)
			{
				Blitter.BlitCameraTexture(cmd, volumetricFogRenderRTHandle, volumetricFogBlurRTHandle, volumetricFogMaterial, volumetricFogHorizontalBlurPassIndex);
				Blitter.BlitCameraTexture(cmd, volumetricFogBlurRTHandle, volumetricFogRenderRTHandle, volumetricFogMaterial, volumetricFogVerticalBlurPassIndex);
			}

			volumetricFogMaterial.SetTexture(VolumetricFogTextureId, volumetricFogRenderRTHandle);

			RTHandle cameraColorRt = renderingData.cameraData.renderer.cameraColorTargetHandle;
			Blitter.BlitCameraTexture(cmd, cameraColorRt, volumetricFogUpsampleCompositionRTHandle, volumetricFogMaterial, volumetricFogUpsampleCompositionPassIndex);
			Blitter.BlitCameraTexture(cmd, volumetricFogUpsampleCompositionRTHandle, cameraColorRt);
		}

		context.ExecuteCommandBuffer(cmd);

		cmd.Clear();

		CommandBufferPool.Release(cmd);
	}

#if UNITY_6000_0_OR_NEWER

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

		CreateRenderGraphTextures(renderGraph, cameraData, out TextureHandle halfResCameraDepthTarget, out TextureHandle volumetricFogRenderTarget, out TextureHandle volumetricFogAuxRenderTarget, out TextureHandle volumetricFogCompositionTarget);

		using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass("Downsample Depth Pass", out PassData passData, downsampleDepthProfilingSampler))
		{
			passData.stage = PassStage.DownsampleDepth;
			passData.target = halfResCameraDepthTarget;
			passData.source = resourceData.cameraDepthTexture;
			passData.material = downsampleDepthMaterial;
			passData.materialPassIndex = downsampleDepthPassIndex;

			builder.SetRenderAttachment(halfResCameraDepthTarget, 0, AccessFlags.WriteAll);
			builder.UseTexture(resourceData.cameraDepthTexture);
			builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
		}

		using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass("Volumetric Fog Render Pass", out PassData passData, profilingSampler))
		{
			passData.stage = PassStage.VolumetricFogRender;
			passData.target = volumetricFogRenderTarget;
			passData.source = halfResCameraDepthTarget;
			passData.material = volumetricFogMaterial;
			passData.materialPassIndex = volumetricFogRenderPassIndex;
			passData.lightData = lightData;
			passData.halfResCameraDepthTarget = halfResCameraDepthTarget;
			passData.orthographic = cameraData.camera.orthographic;

			builder.SetRenderAttachment(volumetricFogRenderTarget, 0, AccessFlags.WriteAll);
			builder.UseTexture(halfResCameraDepthTarget);
			if (resourceData.mainShadowsTexture.IsValid())
				builder.UseTexture(resourceData.mainShadowsTexture);
			if (resourceData.additionalShadowsTexture.IsValid())
				builder.UseTexture(resourceData.additionalShadowsTexture);
			builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
		}

		using (IUnsafeRenderGraphBuilder builder = renderGraph.AddUnsafePass("Volumetric Fog Blur Pass", out PassData passData, profilingSampler))
		{
			passData.stage = PassStage.Blur;
			passData.target = volumetricFogAuxRenderTarget;
			passData.source = volumetricFogRenderTarget;
			passData.material = volumetricFogMaterial;
			passData.materialPassIndex = volumetricFogHorizontalBlurPassIndex;
			passData.materialAdditionalPassIndex = volumetricFogVerticalBlurPassIndex;
			passData.orthographic = cameraData.camera.orthographic;

			// Access flags are theoretically incorrect for one separable blur pass, but it is not
			// going to make any difference.
			builder.UseTexture(volumetricFogRenderTarget, AccessFlags.ReadWrite);
			builder.UseTexture(volumetricFogAuxRenderTarget, AccessFlags.ReadWrite);
			builder.SetRenderFunc((PassData data, UnsafeGraphContext context) => ExecuteUnsafeBlurPass(data, context));
		}

		using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass("Volumetric Fog Upsample Composition Pass", out PassData passData, profilingSampler))
		{
			passData.stage = PassStage.UpsampleComposition;
			passData.target = volumetricFogCompositionTarget;
			passData.source = resourceData.cameraColor;
			passData.material = volumetricFogMaterial;
			passData.materialPassIndex = volumetricFogUpsampleCompositionPassIndex;
			passData.halfResCameraDepthTarget = halfResCameraDepthTarget;
			passData.volumetricFogTarget = volumetricFogRenderTarget;
			passData.orthographic = cameraData.camera.orthographic;

			builder.SetRenderAttachment(volumetricFogCompositionTarget, 0, AccessFlags.WriteAll);
			builder.UseTexture(resourceData.cameraColor);
			builder.UseTexture(resourceData.cameraDepthTexture);
			builder.UseTexture(halfResCameraDepthTarget);
			builder.UseTexture(volumetricFogRenderTarget);
			builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));
		}

		resourceData.cameraColor = volumetricFogCompositionTarget;
	}

#endif

	#endregion

	#region Methods

	/// <summary>
	/// Enables or disables the computations from the main light to influence the volumetric fog.
	/// </summary>
	/// <param name="volumetricFogMaterial"></param>
	/// <param name="enabled"></param>
	private static void EnableMainLightContribution(Material volumetricFogMaterial, bool enabled)
	{
		if (enabled)
			volumetricFogMaterial.DisableKeyword("_MAIN_LIGHT_CONTRIBUTION_DISABLED");
		else
			volumetricFogMaterial.EnableKeyword("_MAIN_LIGHT_CONTRIBUTION_DISABLED");
	}

	/// <summary>
	/// Enables or disables the computations from additional lights to influence the volumetric fog.
	/// </summary>
	/// <param name="volumetricFogMaterial"></param>
	/// <param name="enabled"></param>
	private static void EnableAdditionalLightsContribution(Material volumetricFogMaterial, bool enabled)
	{
		if (enabled)
			volumetricFogMaterial.DisableKeyword("_ADDITIONAL_LIGHTS_CONTRIBUTION_DISABLED");
		else
			volumetricFogMaterial.EnableKeyword("_ADDITIONAL_LIGHTS_CONTRIBUTION_DISABLED");
	}

	private static void UpdateVolumetricFogMaterialProperties(Material volumetricFogMaterial, NativeArray<VisibleLight> visibleLights, int mainLightIndex, int additionalLightsCount)
	{
		VolumetricFogVolumeComponent fogVolume = VolumeManager.instance.stack.GetComponent<VolumetricFogVolumeComponent>();

		bool enableMainLightContribution = fogVolume.enableMainLightContribution.value && fogVolume.scattering.value > 0.0f && mainLightIndex > -1;
		bool enableAdditionalLightsContribution = fogVolume.enableAdditionalLightsContribution.value && additionalLightsCount > 0;
		EnableMainLightContribution(volumetricFogMaterial, enableMainLightContribution);
		EnableAdditionalLightsContribution(volumetricFogMaterial, enableAdditionalLightsContribution);
		UpdateLightsProperties(enableMainLightContribution, enableAdditionalLightsContribution, fogVolume, volumetricFogMaterial, visibleLights, mainLightIndex);

		float groundHeight = (fogVolume.enableGround.overrideState && fogVolume.enableGround.value) ? fogVolume.groundHeight.value : float.MinValue;
		float absortion = 1.0f / fogVolume.attenuationDistance.value;
		volumetricFogMaterial.SetInteger(FrameCountId, Time.renderedFrameCount % 64);
		volumetricFogMaterial.SetInteger(CustomAdditionalLightsCountId, additionalLightsCount);
		volumetricFogMaterial.SetFloat(DistanceId, fogVolume.distance.value);
		volumetricFogMaterial.SetFloat(BaseHeightId, fogVolume.baseHeight.value);
		volumetricFogMaterial.SetFloat(MaximumHeightId, fogVolume.maximumHeight.value);
		volumetricFogMaterial.SetFloat(GroundHeightId, groundHeight);
		volumetricFogMaterial.SetFloat(DensityId, fogVolume.density.value);
		volumetricFogMaterial.SetFloat(AbsortionId, absortion);
		volumetricFogMaterial.SetColor(TintId, fogVolume.tint.value);
		volumetricFogMaterial.SetInteger(MaxStepsId, fogVolume.maxSteps.value);
	}

	/// <summary>
	/// Updates the lights parameters from the material.
	/// </summary>
	/// <param name="enableMainLightContribution"></param>
	/// <param name="enableAdditionalLightsContribution"></param>
	/// <param name="fogVolume"></param>
	/// <param name="volumetricFogMaterial"></param>
	/// <param name="visibleLights"></param>
	/// <param name="mainLightIndex"></param>
	private static void UpdateLightsProperties(bool enableMainLightContribution, bool enableAdditionalLightsContribution, VolumetricFogVolumeComponent fogVolume, Material volumetricFogMaterial, NativeArray<VisibleLight> visibleLights, int mainLightIndex)
	{
		if (!enableMainLightContribution && !enableAdditionalLightsContribution)
			return;

		if (enableMainLightContribution)
		{
			int lastIndex = visibleLights.Length - 1;
			Anisotropies[lastIndex] = fogVolume.anisotropy.value;
			Scatterings[lastIndex] = fogVolume.scattering.value;
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
					if (volumetricLight.enabled)
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

		volumetricFogMaterial.SetFloatArray(AnisotropiesArrayId, Anisotropies);
		volumetricFogMaterial.SetFloatArray(ScatteringsArrayId, Scatterings);
		volumetricFogMaterial.SetFloatArray(RadiiSqArrayId, RadiiSq);
	}

#if UNITY_6000_0_OR_NEWER

	/// <summary>
	/// Creates and returns all the necessary render graph textures.
	/// </summary>
	/// <param name="renderGraph"></param>
	/// <param name="cameraData"></param>
	/// <param name="halfResCameraDepthTarget"></param>
	/// <param name="volumetricFogRenderTarget"></param>
	/// <param name="volumetricFogAuxRenderTarget"></param>
	/// <param name="volumetricFogCompositionTarget"></param>
	private void CreateRenderGraphTextures(RenderGraph renderGraph, UniversalCameraData cameraData, out TextureHandle halfResCameraDepthTarget, out TextureHandle volumetricFogRenderTarget, out TextureHandle volumetricFogAuxRenderTarget, out TextureHandle volumetricFogCompositionTarget)
	{
		RenderTextureDescriptor cameraTargetDescriptor = cameraData.cameraTargetDescriptor;
		cameraTargetDescriptor.depthBufferBits = (int)DepthBits.None;

		RenderTextureFormat originalColorFormat = cameraTargetDescriptor.colorFormat;
		Vector2Int originalResolution = new Vector2Int(cameraTargetDescriptor.width, cameraTargetDescriptor.height);

		cameraTargetDescriptor.width /= 2;
		cameraTargetDescriptor.height /= 2;
		cameraTargetDescriptor.graphicsFormat = GraphicsFormat.R32_SFloat;
		halfResCameraDepthTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, HalfResCameraDepthRTName, false);

		cameraTargetDescriptor.colorFormat = RenderTextureFormat.ARGBHalf;
		volumetricFogRenderTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, VolumetricFogRenderRTName, false);
		volumetricFogAuxRenderTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, VolumetricFogBlurRTName, false);

		cameraTargetDescriptor.width = originalResolution.x;
		cameraTargetDescriptor.height = originalResolution.y;
		cameraTargetDescriptor.colorFormat = originalColorFormat;
		volumetricFogCompositionTarget = UniversalRenderer.CreateRenderGraphTexture(renderGraph, cameraTargetDescriptor, VolumetricFogUpsampleCompositionRTName, false);
	}

	/// <summary>
	/// Executes the pass with the information from the pass data.
	/// </summary>
	/// <param name="passData"></param>
	/// <param name="context"></param>
	private static void ExecutePass(PassData passData, RasterGraphContext context)
	{
		PassStage stage = passData.stage;

		if (stage == PassStage.VolumetricFogRender)
			UpdateVolumetricFogMaterialProperties(passData.material, passData.lightData.visibleLights, passData.lightData.mainLightIndex, passData.lightData.additionalLightsCount, passData.orthographic);
		else if (stage == PassStage.UpsampleComposition)
			passData.material.SetTexture(VolumetricFogTextureId, passData.volumetricFogTarget);

		Blitter.BlitTexture(context.cmd, passData.source, Vector2.one, passData.material, passData.materialPassIndex);

		if (stage == PassStage.DownsampleDepth)
			passData.material.SetTexture(HalfResCameraDepthTextureId, passData.halfResCameraDepthTarget);
	}

	/// <summary>
	/// Executes the unsafe pass that does up to multiple separable blurs to the volumetric fog.
	/// </summary>
	/// <param name="passData"></param>
	/// <param name="context"></param>
	private static void ExecuteUnsafeBlurPass(PassData passData, UnsafeGraphContext context)
	{
		CommandBuffer unsafeCmd = CommandBufferHelpers.GetNativeCommandBuffer(context.cmd);

		int blurIterations = VolumeManager.instance.stack.GetComponent<VolumetricFogVolumeComponent>().blurIterations.value;

		for (int i = 0; i < blurIterations; ++i)
		{
			Blitter.BlitCameraTexture(unsafeCmd, passData.source, passData.target, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, passData.material, passData.materialPassIndex);
			Blitter.BlitCameraTexture(unsafeCmd, passData.target, passData.source, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, passData.material, passData.materialAdditionalPassIndex);
		}
	}

#endif

	/// <summary>
	/// Disposes the resources used by this pass.
	/// </summary>
	public void Dispose()
	{
		halfResCameraDepthRTHandle?.Release();
		volumetricFogRenderRTHandle?.Release();
		volumetricFogBlurRTHandle?.Release();
		volumetricFogUpsampleCompositionRTHandle?.Release();
	}

	#endregion
}