Shader "Hidden/Raymarch Fullscreen"
{
    Properties
    {
        _NumSteps ("Number of Raymarch Steps", Int) = 100
        _RefinementSteps ("Refinement Steps", Int) = 25
        _DepthScale ("Depth Scale", Float) = 30.0
        _Diff ("Difference Threshold", Float) = 150.0
        _Edge ("Edge Threshold", Float) = 0.025
        _Infill ("Infill", Int) = 0
        _Debug ("Debug", Int) = 0
        _Offset ("Offset", Float) = 0.0
    }

    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #pragma multi_compile EDGE_PASS

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
        
    TEXTURE2D_X(_EdgeTex);

    TEXTURE2D(_MainTex);
    TEXTURE2D(_DepthTex);
    TEXTURE2D(_InfillTex);

    SamplerState sampler_MainTex;
    SamplerState sampler_DepthTex;

    int _NumSteps;
    int _RefinementSteps;
    float _DepthScale;
    float _Diff;
    float _Edge;
    int _Infill;
    int _Debug;
    float _Offset;

    int refinementPass;

    float2 GetUV(int eyeIndex, float3 uvOffset) {
        // normal to the caputure position
        float3 cameraOrigin = float3(-0.03 + eyeIndex * 0.06, 0, 0);
        float3 uvNormal = normalize(cameraOrigin - uvOffset);
        float3 uvWorld = uvOffset + uvNormal * (uvOffset.z - 0.2) / -uvNormal.z;
        return float2((uvWorld.x - cameraOrigin.x) / 0.8 + 0.25 + 0.5 * eyeIndex, (uvWorld.y - cameraOrigin.y) / 0.4 + 0.5);
    }

    float3 GetOffset(float percentage, float3 delta) {
        // make smaller steps closer to the camera
        float dist = pow(percentage, 6);
        return delta * dist;
    }

    float GetDepth(float2 uv) {
        float sampledHeight = SAMPLE_TEXTURE2D(_DepthTex, sampler_DepthTex, uv).r;
        return sampledHeight * _DepthScale;
    }

    bool IsPointInFrustum(float3 p)
    {
        float fov = 90;
        float aspect = 1.0;
        float nearClip = 0;
        float farClip = 30.0;

        float yMax = p.z * tan(radians(fov * 0.5));
        float xMax = yMax * aspect;

        return abs(p.x) <= xMax && abs(p.y) <= yMax;
    }

    float4 raymarch(float3 positionWS, float startOffset, int eyeIndex, int steps, out float outputDepth) {
        outputDepth = 1;

        float3 rayOrigin = _WorldSpaceCameraPos;
        float3 rayDir = normalize(positionWS - _WorldSpaceCameraPos);

        if (rayDir.z < 0)
            return float4(0, 0, 0, 0);

        // start from the image plane
        float3 rayStart = rayOrigin;
        if (rayStart.z < 0.2)
            rayStart = rayOrigin + rayDir * ((0.2 - rayOrigin.z) / rayDir.z);

        // index of the texture we are currently sampeling
        int texIndex = eyeIndex;
        float meters = _DepthScale;
        
        float3 position = rayStart;
        float3 cameraNormal = rayDir;

        // ray position near/far
        float3 nearPosition = position + cameraNormal * (meters / cameraNormal.z) * max(0, startOffset - ((position.z - 0.2) / meters));
        float3 distPosition = position + cameraNormal * (meters / cameraNormal.z);
        
        // direction of the line where we sample pixels
        float2 uvDelta = GetUV(texIndex, distPosition) - GetUV(texIndex, nearPosition);
        float lengthSq = dot(uvDelta, uvDelta);
        float2 uvDir = lengthSq > 0.000001 ? normalize(uvDelta) / 2560.0 : float2(0.0, 0.0);
        
        // delta between nearest and farthest position
        float3 delta = distPosition - nearPosition; 
                
        float3 uvOffset = nearPosition;
        float currentLayerHeight = 0.0;
        
        float invSteps = 1 / float(steps);
        float invRefinementSteps = 1 / float(_RefinementSteps);

        int firstSample = 1;

        [loop]
        for (int j = 0; j < steps; j++)
        {
            // make smaller steps closer to the camera
            uvOffset = nearPosition + GetOffset(j * invSteps, delta);
            currentLayerHeight = (uvOffset.z - 0.2);
            
            // outside of the capture frustum?
            float farClip = 30.0;
            if (!IsPointInFrustum(uvOffset)) {
                continue;
            }

            // project the uvOffset
            float2 uv = GetUV(texIndex, uvOffset);
            float sampledHeight = GetDepth(uv);

            // hit something?
            if (sampledHeight <= currentLayerHeight)
            {       
                float3 uvOffsetNear = nearPosition + GetOffset((j - 1) * invSteps, delta);
                float3 uvOffsetFar = uvOffset;

                // first sample is inside something happens in the edge pass sampling behind objects
                if (firstSample)
                    return float4(0, 0, 0, 0);

                // refine the sample
                [loop]
                for (int u = 0; u <= _RefinementSteps; u++)
                {
                    // make smaller steps closer to the camera
                    uvOffset = lerp(uvOffsetNear, uvOffsetFar, u * invRefinementSteps);
                    // project the uvOffset
                    uv = GetUV(texIndex, uvOffset);
                    sampledHeight = GetDepth(uv);

                    // hit something?
                    currentLayerHeight = (uvOffset.z - 0.2);
                    if (sampledHeight <= currentLayerHeight)
                    {
                        float stepSize = 0.5;
                        float heightBack = GetDepth(uv - uvDir * stepSize);
                        float heightForward = GetDepth(uv + uvDir * stepSize);
                        // does not work great and should be replaced with something better
                        float threshold = _Edge / (1 / (currentLayerHeight));

                        float back = heightBack - currentLayerHeight;
                        float forward = heightForward - currentLayerHeight;

                        if (_Debug) {
                            outputDepth = currentLayerHeight / float(meters);
                            return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                        }

                        // sampling from the side?
                        if ((abs(back) > threshold && abs(forward) > threshold) ||
                            (forward < -threshold && back >= -threshold)) {
                            outputDepth = 0;
                            
                            // return SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 6);
                            // return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                            // return float4(1, 0, 1, 1);

                            if(_Infill)
                                return SAMPLE_TEXTURE2D(_InfillTex, sampler_MainTex, uv - uvDir * stepSize * 6);
                            else
                                return SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 6);
                        }
                        else
                        {
                            outputDepth = currentLayerHeight / float(meters);
                            return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                        }
                    }
                }
            }

            firstSample = 0;
        }
        
        if (!IsPointInFrustum(uvOffset)) {
            return float4(0, 0, 0, 1);
        }
        
        float2 uv = GetUV(eyeIndex, uvOffset);
        return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
    }
    
    float3 ScreenToWorldPosition(float2 positionCS, float rawDepth)
    {
        // Convert from pixel space to NDC
        float2 uv = positionCS * _ScreenSize.zw; // _ScreenSize.zw = 1/screen resolution
        float2 ndcXY = uv * 2.0 - 1.0;

        ndcXY.y = -ndcXY.y;

        // Reconstruct clip space position
        float4 clipPos = float4(ndcXY, rawDepth, 1.0);

        // Transform back to world space using inverse VP
        float4 worldPos = mul(UNITY_MATRIX_I_VP, clipPos);
        worldPos.xyz /= worldPos.w; // Perspective divide

        return worldPos.xyz;
    }

    float4 FullScreenPass(Varyings varyings, out float outputDepth : SV_Depth) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, 0, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        
        refinementPass = 0;

        // posInput.positionWS is somehow dependent on far plane of the camera
        // so to get correct results the far plane needs to be set far away ~500
        return raymarch(posInput.positionWS, _Offset, unity_StereoEyeIndex, _NumSteps, outputDepth);
    }

    float4 RefinementPass(Varyings varyings, out float outputDepth : SV_Depth) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        
        int steps = 25;
        refinementPass = 1;

        // sample edge texture
        float edge = SAMPLE_TEXTURE2D_X(_EdgeTex, s_point_clamp_sampler, posInput.positionNDC).r;
        outputDepth = 0;

        if (edge > 0)
        {
            PositionInputs pos0 = GetPositionInput(varyings.positionCS.xy + int2( 1,  0), _ScreenSize.zw, 0, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
            PositionInputs pos1 = GetPositionInput(varyings.positionCS.xy + int2( 0,  1), _ScreenSize.zw, 0, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

            float3 right = pos0.positionWS - posInput.positionWS;
            float3 down = pos1.positionWS - posInput.positionWS;

            float offset = 0.25;
            float depth0, depth1, depth2, depth3;

            edge = edge - 0.01;

            float4 color0 = raymarch(posInput.positionWS - right * offset - down * offset, edge, unity_StereoEyeIndex, steps, depth0);
            float4 color1 = raymarch(posInput.positionWS - right * offset + down * offset, edge, unity_StereoEyeIndex, steps, depth1);
            float4 color2 = raymarch(posInput.positionWS + right * offset - down * offset, edge, unity_StereoEyeIndex, steps, depth2);
            float4 color3 = raymarch(posInput.positionWS + right * offset + down * offset, edge, unity_StereoEyeIndex, steps, depth3);
         
            outputDepth = depth0 * 0.25 + depth1 * 0.25 + depth2 * 0.25 + depth3 * 0.25;
            
            return float4((color0.rgb + color1.rgb + color2.rgb + color3.rgb) /
                   (color0.a + color1.a + color2.a + color3.a), (color0.a + color1.a + color2.a + color3.a) / 4);
        }
        
        outputDepth = 0;
        return float4(0, 0, 0, 0);
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" "RenderType"="Opaque" "Queue"="Geometry+1" }
        Pass
        {
            Name "Custom Pass 0"

            ZWrite On
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
        Pass
        {
            Name "Custom Pass 1"

            ZWrite On
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment RefinementPass
            ENDHLSL
        }
    }
    Fallback Off
}
