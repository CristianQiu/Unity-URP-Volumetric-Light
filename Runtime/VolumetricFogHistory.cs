using UnityEngine;
using UnityEngine.Rendering;

public class VolumetricFogHistory : CameraHistoryItem
{
	private int uniqueId;

	// Add a hash key to track changes to the descriptor.
	private Hash128 m_DescKey;

	public RTHandle CurrentTexture { get { return GetCurrentFrameRT(uniqueId); } }
	public RTHandle PreviousTexture { get { return GetPreviousFrameRT(uniqueId); } }

	public override void OnCreate(BufferedRTHandleSystem owner, uint typeId)
	{
		// Call the OnCreate method of the parent class
		base.OnCreate(owner, typeId);

		// Generate the unique id
		uniqueId = MakeId(0);
	}

	public override void Reset()
	{
		ReleaseHistoryFrameRT(uniqueId);
	}

	// The render pass calls the Update method every frame, to initialize, update, or dispose of the textures.
	public void Update(RenderTextureDescriptor textureDescriptor)
	{
		// Dispose of the textures if the memory needs to be reallocated.
		if (m_DescKey != Hash128.Compute(ref textureDescriptor))
			ReleaseHistoryFrameRT(uniqueId);

		// Allocate the memory for the textures if it's not already allocated.
		if (CurrentTexture == null)
		{
			AllocHistoryFrameRT(uniqueId, 2, ref textureDescriptor, "HistoryTexture");

			// Store the descriptor and hash key for future changes.
			//m_Descriptor = textureDescriptor;
			m_DescKey = Hash128.Compute(ref textureDescriptor);
		}
	}
}