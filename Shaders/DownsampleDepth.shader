Shader "Hidden/DownsampleDepth"
{
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "DownsampleDepth"

            ZTest Always
            ZWrite Off
            Cull Off
            Blend Off
            ColorMask R

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            #pragma editor_sync_compilation

            #pragma vertex Vert
            #pragma fragment Frag

            float Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float4 depths;

#if SHADER_TARGET >= 45
                depths = GATHER_RED_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, input.texcoord);
#else
                uint2 fullResTopLeftCorner = uint2(input.positionCS.xy * 2.0);

                depths.x = LoadSceneDepth(fullResTopLeftCorner);
                depths.y = LoadSceneDepth(fullResTopLeftCorner + uint2(1, 0));
                depths.z = LoadSceneDepth(fullResTopLeftCorner + uint2(1, 1));
                depths.w = LoadSceneDepth(fullResTopLeftCorner + uint2(0, 1));
#endif
                float minDepth = Min3(depths.x, depths.y, min(depths.z, depths.w));
                float maxDepth = Max3(depths.x, depths.y, max(depths.z, depths.w));

                return (uint(input.positionCS.x + input.positionCS.y) & 1) > 0 ? minDepth : maxDepth;
            }

            ENDHLSL
        }
    }

    Fallback Off
}