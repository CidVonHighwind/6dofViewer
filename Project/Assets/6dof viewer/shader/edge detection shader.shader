Shader "Hidden/Edge Detection Fullscreen"
{
    Properties
    {
        _Threshold ("Threshold", Float) = 0.075
    }

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

    TEXTURE2D_X(_InputTexture);
    TEXTURE2D_X(_DepthTexture);
    
    float _Threshold;

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        uint scale = 1;
        uint2 pixelCoord = posInput.positionSS * scale;

        // Lade benachbarte Tiefen
        float depthCenter = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 0,  0) * scale).r;
        float depthLeft   = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2(-1,  0) * scale).r;
        float depthRight  = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 1,  0) * scale).r;
        float depthUp     = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 0, -1) * scale).r;
        float depthDown   = LOAD_TEXTURE2D_X(_DepthTexture, pixelCoord + uint2( 0,  1) * scale).r;

        depthCenter = depthCenter <= 0 ? 2 : depthCenter;
        depthLeft = depthLeft <= 0 ? 2 : depthLeft;
        depthRight = depthRight <= 0 ? 2 : depthRight;
        depthUp = depthUp <= 0 ? 2 : depthUp;
        depthDown = depthDown <= 0 ? 2 : depthDown;

        // Differenz berechnen (Gradient)
        float dx = abs(depthLeft - depthRight);
        float dy = abs(depthUp - depthDown);
        float edge = sqrt(dx * dx + dy * dy);
                
        float depthMin = min(depthCenter, min(depthLeft, min(depthRight, min(depthUp, depthDown))));

        // Schwellenwert (Threshold)
        float edgeDetected = edge > depthCenter * _Threshold ? 1.0 : 0.0;
        return float4(float3(depthMin, 0, 0) * edgeDetected, 1);
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
    }
    Fallback Off
}
