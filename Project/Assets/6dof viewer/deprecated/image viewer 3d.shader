
Shader "Unlit/3d image viewer shader"
{
    Properties
    {
        _MainTex ("Color", 2D) = "white" {}
        _DepthTex ("Depth", 2D) = "white" {}

        _NumSteps ("Step Count", Range(50, 1000)) = 300
        _RefinementSteps ("Refinement Step Count", Range(1, 100)) = 25
        _Diff ("Diff", Range(0, 1500)) = 150
        _DepthScale ("Depth Scale", Range(0, 50)) = 30
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite On
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 100

        Pass
        {
            Name "CustomOnly"
            Tags { "LightMode" = "CustomOnly" }

            CGPROGRAM
            
            #pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                
                UNITY_VERTEX_INPUT_INSTANCE_ID //Insert
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD2;
                float2 screenUV : TEXCOORD3;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            struct fOut  {
                fixed4 color : SV_Target0;
                fixed depth : SV_Depth;
            };

            float4 _MainTex_ST;

            sampler2D _MainTex;
            sampler2D _DepthTex;

            // edge texture used for refinement step
            UNITY_DECLARE_TEX2DARRAY(_EdgeTex);

            int _NumSteps;
            int _RefinementSteps;
            int _Diff;
            float _DepthScale;
            int _EdgePass;

            v2f vert (appdata v)
            {
                v2f o;
                
                UNITY_SETUP_INSTANCE_ID(v); // VR
                UNITY_INITIALIZE_OUTPUT(v2f, o); // VR
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); // VR

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                float4 clipPos = UnityObjectToClipPos(v.vertex); // clip space
                float2 screenUV = (clipPos.xy / clipPos.w) * 0.5 + 0.5;
                o.screenUV = float2(screenUV.x, -screenUV.y);

                return o;
            }
            
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
                float div = _Diff / 100000.0;
                float sampledHeight = tex2D(_DepthTex, uv).r;
                return ((div / sampledHeight) - div) * _DepthScale;
            }

            fOut raymarch(float3 position, float startOffset, int eyeIndex) {
                fOut o;
                o.color = float4(0, 0, 0, 0);
                o.depth = 1;
                
                // index of the texture we are currently sampeling
                int texIndex = eyeIndex;
                float meters = _DepthScale;
                
                float3 cameraNormal = normalize(position - _WorldSpaceCameraPos);

                // ray position near/far
                float3 nearPosition = position + cameraNormal * (meters / cameraNormal.z) * startOffset;
                float3 distPosition = position + cameraNormal * (meters / cameraNormal.z);
                
                // delta between nearest and farthest position
                float3 delta = distPosition - nearPosition; 
                
                float3 uvOffset = nearPosition;
                float currentLayerHeight = 0.0;
                
                [loop]
                for (int j = 0; j < _NumSteps; j++)
                {
                    // make smaller steps closer to the camera
                    uvOffset = nearPosition + GetOffset(j / float(_NumSteps), delta);
                    currentLayerHeight = (uvOffset.z - position.z);

                    // project the uvOffset
                    float2 uv = GetUV(texIndex, uvOffset);
                    
                    // moved outside of the image?
                    if (uv.x < 0.5 * texIndex || uv.x > 0.5 + 0.5 * texIndex || uv.y < 0 || uv.y > 1) {
                        o.color = float4(0, 0, 0, 0);
                        return o;
                    }

                    float sampledHeight = GetDepth(uv);

                    // hit something?
                    if (sampledHeight <= currentLayerHeight)
                    {
                        // o.color = tex2D(_MainTex, uv);
                        // o.depth = currentLayerHeight / float(meters);
                        // if (sampledHeight - currentLayerHeight < -0.025 * currentLayerHeight)
                        //     o.color = float4(1, 0, 1, 1);
                        // return o;

                        texIndex = eyeIndex;
                        
                        float3 uvOffsetNear = nearPosition + GetOffset((j - 1) / float(_NumSteps), delta);
                        float3 uvOffsetFar = uvOffset;
                        // direction of the line where we sample pixels
                        float2 delta = GetUV(texIndex, uvOffsetFar) - GetUV(texIndex, uvOffsetNear);
                        float lengthSq = dot(delta, delta);
                        float2 uvDir = lengthSq > 0.00001 ? normalize(delta) / 1280.0 : float2(0.0, 0.0);

                        [loop]
                        for (int u = 0; u < _RefinementSteps; u++)
                        {
                            // make smaller steps closer to the camera
                            uvOffset = lerp(uvOffsetNear, uvOffsetFar, (u + 1) / float(_RefinementSteps));
                            // project the uvOffset
                            uv = GetUV(texIndex, uvOffset);
                            sampledHeight = GetDepth(uv);

                            // hit something?
                            currentLayerHeight = (uvOffset.z - position.z);
                            if (sampledHeight <= currentLayerHeight)
                            {
                                float stepSize = 0.5;
                                float heightBack = GetDepth(uv - uvDir * stepSize);
                                float heightForward = GetDepth(uv + uvDir * stepSize);
                                
                                // sampling from the side? => sample filler texture
                                if (heightForward - currentLayerHeight < -0.05 * currentLayerHeight) {
                                    o.color = tex2Dlod(_MainTex, float4(uv, 0, 6));
                                }
                                else
                                {
                                    o.depth = currentLayerHeight / float(meters);
                                    o.color = tex2D(_MainTex, uv);
                                }

                                return o;
                            }
                        }
                    }
                }
                                
                float2 uv = GetUV(eyeIndex, uvOffset);
                o.depth = currentLayerHeight / float(meters);
                o.color = tex2D(_MainTex, uv);

                return o;
            }

            fOut frag(v2f i) {
                fOut o;
                o.color = float4(0, 0, 0, 0);
                o.depth = 0;
                
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                int eyeIndex = unity_StereoEyeIndex;

                o.color.r = i.screenUV.x;
                return o;

                // only process edges
                if (_EdgePass) {
                    float edge = UNITY_SAMPLE_TEX2DARRAY(_EdgeTex, float3(i.screenUV, eyeIndex)).r;
                    if (edge <= 0)
                        return o;
                
                    o.color = float4(1, 0, 1, 1);
                    return o;

                    // float3 pos0 = i.worldPos - ddx(i.worldPos) * 0.25 - ddy(i.worldPos) * 0.25;
                    // float3 pos1 = i.worldPos - ddx(i.worldPos) * 0.25 + ddy(i.worldPos) * 0.25;
                    // float3 pos2 = i.worldPos + ddx(i.worldPos) * 0.25 - ddy(i.worldPos) * 0.25;
                    // float3 pos3 = i.worldPos + ddx(i.worldPos) * 0.25 + ddy(i.worldPos) * 0.25;

                    // float start = edge;
                    // start = 0;

                    // fOut o0 = raymarch(pos0, start, eyeIndex);
                    // fOut o1 = raymarch(pos1, start, eyeIndex);
                    // fOut o2 = raymarch(pos2, start, eyeIndex);
                    // fOut o3 = raymarch(pos3, start, eyeIndex);
                    
                    // o.color = o0.color * 0.25 + o1.color * 0.25 + o2.color * 0.25 + o3.color * 0.25;
                    // return o;
                }

                o = raymarch(i.worldPos, 0, eyeIndex);
                return o;
            }

            ENDCG
        }
    }
}
