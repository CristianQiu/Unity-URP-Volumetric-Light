using UnityEngine.Rendering.Universal;

/// <summary>
/// Rendering resolution that the volumetric fog will use to render the fog, by downsampling the
/// depth texture first.
/// </summary>
public enum VolumetricFogResolution : byte
{
	Half = 2,
	Quarter = 4,
}

/// <summary>
/// Render pass events for the volumetric fog. Matches the ones in the Universal Render Pipeline.
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
	public const VolumetricFogResolution DefaultResolution = VolumetricFogResolution.Half;

	public const RenderPassEvent DefaultRenderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
	public const VolumetricFogRenderPassEvent DefaultVolumetricFogRenderPassEvent = (VolumetricFogRenderPassEvent)DefaultRenderPassEvent;
}