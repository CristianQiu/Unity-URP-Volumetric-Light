/// <summary>
/// Render pass events for the volumetric fog. Matches the ones in the Universal Render Pipeline.
/// </summary>
public enum VolumetricFogRenderPassEvent
{
	BeforeRenderingTransparents = 450,
	AfterRenderingTransparents = 500,
	BeforeRenderingPostProcessing = 550
}