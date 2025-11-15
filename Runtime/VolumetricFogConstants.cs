using UnityEngine.Rendering.Universal;

/// <summary>
/// The noise mode used by the volumetric fog.
/// </summary>
public enum VolumetricFogNoiseMode : byte
{
	None = 0,
	Noise3DTexture = 1,
	NoiseAndDistortion3DTextures = 2
}

/// <summary>
/// Render pass events for the volumetric fog. They match the ones in the Universal Render Pipeline.
/// </summary>
public enum VolumetricFogRenderPassEvent
{
	AfterRenderingSkybox = RenderPassEvent.AfterRenderingSkybox,
	BeforeRenderingTransparents = RenderPassEvent.BeforeRenderingTransparents,
	AfterRenderingTransparents = RenderPassEvent.AfterRenderingTransparents,
	BeforeRenderingPostProcessing = RenderPassEvent.BeforeRenderingPostProcessing
}

/// <summary>
/// Constant definitions for the volumetric fog.
/// </summary>
public static class VolumetricFogConstants
{
	public const VolumetricFogNoiseMode DefaultVolumetricFogNoiseMode = VolumetricFogNoiseMode.None;

	public const RenderPassEvent DefaultRenderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
	public const VolumetricFogRenderPassEvent DefaultVolumetricFogRenderPassEvent = (VolumetricFogRenderPassEvent)DefaultRenderPassEvent;
}