Shader "Hidden/Downsample Fullscreen"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

    // The PositionInputs struct allow you to retrieve a lot of useful information for your fullScreenShader:
    // struct PositionInputs
    // {
    //     float3 positionWS;  // World space position (could be camera-relative)
    //     float2 positionNDC; // Normalized screen coordinates within the viewport    : [0, 1) (with the half-pixel offset)
    //     uint2  positionSS;  // Screen space pixel coordinates                       : [0, NumPixels)
    //     uint2  tileCoord;   // Screen tile coordinates                              : [0, NumTiles)
    //     float  deviceDepth; // Depth from the depth buffer                          : [0, 1] (typically reversed)
    //     float  linearDepth; // View space Z coordinate                              : [Near, Far]
    // };

    // To sample custom buffers, you have access to these functions:
    // But be careful, on most platforms you can't sample to the bound color buffer. It means that you
    // can't use the SampleCustomColor when the pass color buffer is set to custom (and same for camera the buffer).
    // float4 SampleCustomColor(float2 uv);
    // float4 LoadCustomColor(uint2 pixelCoords);
    // float LoadCustomDepth(uint2 pixelCoords);
    // float SampleCustomDepth(float2 uv);

    // There are also a lot of utility function you can use inside Common.hlsl and Color.hlsl,
    // you can check them out in the source code of the core SRP package.

    TEXTURE2D_X(_DepthTexture);

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        uint scale = 2;
        uint2 pixelCoord = posInput.positionSS * scale;

        float depth0 = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 0,  0)).r;
        float depth1 = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 1,  0)).r;
        float depth2 = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 0,  1)).r;
        float depth3 = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 1,  1)).r;
                
        depth0 = depth0 <= 0 ? 2 : depth0;
        depth1 = depth1 <= 0 ? 2 : depth1;
        depth2 = depth2 <= 0 ? 2 : depth2;
        depth3 = depth3 <= 0 ? 2 : depth3;

        float depthMin = min(depth0, min(depth1, min(depth2, depth3)));

        if (depthMin >= 2)
            return float4(0, 0, 0, 0);

        return float4(float3(1, 0, 1) * depthMin, 1);
    }
        
    float4 EdgePass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        uint scale = 2;
        uint2 pixelCoord = posInput.positionSS * scale;

        float pixel0 = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 0,  0)).r;
        float pixel1 = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 1,  0)).r;
        float pixel2 = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 0,  1)).r;
        float pixel3 = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 1,  1)).r;

        float depth0 = pixel0.r <= 0 ? 1 : pixel0;
        float depth1 = pixel1.r <= 0 ? 1 : pixel1;
        float depth2 = pixel2.r <= 0 ? 1 : pixel2;
        float depth3 = pixel3.r <= 0 ? 1 : pixel3;
        
        float depthMax = min(depth0, min(depth1, min(depth2, depth3)));
        depthMax = depthMax >= 1 ? 0 : depthMax;

        return float4(float3(1, 0, 1) * depthMax, 1);
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Name "Depth Pass"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
        Pass
        {
            Name "Edge Pass"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment EdgePass
            ENDHLSL
        }
    }
    Fallback Off
}
