Shader "Unlit/3d 180 shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DepthTex ("Texture", 2D) = "white" {}
        _Eye ("Eye", Range(0, 1)) = 0
        _DepthScale ("Depth Scale", Range(0, 0.6)) = 0
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 100
        Cull Front

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            #define PI 3.14159265

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 spherePosition : TEXCOORD1;
                float3 worldPos : TEXCOORD2;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            sampler2D _DepthTex;
            
            int _Eye = 0;
            float _DepthScale = 1.0;

            v2f vert (appdata v)
            {
                v2f o;
                
                UNITY_SETUP_INSTANCE_ID(v); // VR
                UNITY_INITIALIZE_OUTPUT(v2f, o); // VR
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); // VR

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.spherePosition = v.vertex.xyz;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                return o;
            }

            float2 GetAngle(float3 dir)
            {
                float t = atan2(dir.x, dir.z);  // horizontal angle
                float p = asin(dir.y);          // vertical angle

                return float2(t, p);
            }

            float2 GetUV(float2 angle, int eye)
            {
                float u = angle.x / PI + 0.5;
                float v = angle.y / (PI) + 0.5;

                return float2(angle.x / PI / 2 + 0.25 + 0.5 * eye, angle.y / PI + 0.5);
            }
            
            float GetFade(float3 position, float3 coneDir, float cosTheta) {
                float dotProdCamera = dot(normalize(position), coneDir);
                return clamp(abs(dotProdCamera - cosTheta) / 0.05, 0, 1);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);                             // VR
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);            // VR
                
                // only show one side
                // if (i.spherePosition.z < 0.0)
                //     return float4(0, 0, 0, 0);
                
                int eyeIndex = unity_StereoEyeIndex;
                // eyeIndex = _Eye;
                
                if (eyeIndex != _Eye)
                   discard;

                
                const int numSteps = 400;
                const float rayDepth = 6;



                float3 cameraWorldPosition = _WorldSpaceCameraPos;
                float3 cameraNormal = normalize(i.worldPos - cameraWorldPosition);
                float2 cameraAngle = GetAngle(cameraNormal);
                // camera position projected onto the farthest depth
                float3 distPosition = i.worldPos + cameraNormal * (rayDepth / length(cameraNormal));
                
                // normal to the caputure position
                float3 cameraOrigin = float3(0, 0, 0);
                if (eyeIndex == 0)
                    cameraOrigin = float3(-0.03, 0, 0);
                else
                    cameraOrigin = float3(0.03, 0, 0);
       
                                
                float3 delta = distPosition - i.worldPos; 
                
                float3 uvOffset = i.worldPos;
                float currentLayerHeight = 0.0;
                
                float3 coneDir = float3(0, 0, 1);
                float coneAngle = 64;
                float cosTheta = cos(radians(coneAngle));
                
                // camera looking inside the cone?
                float dotProdCamera = dot(cameraNormal, coneDir);

                // return tex2D(_MainTex, GetUV(normalize(delta), eyeIndex));
                
                bool first = true;

                [loop]
                for (int j = 0; j < numSteps; j++)
                {
                    // the steps are closer together close to the camera
                    float dist = pow(float(j) / numSteps, 2);
                    uvOffset = i.worldPos + delta * dist;
                    currentLayerHeight = (length(uvOffset) - 0.125) / rayDepth; // 0-1

                    // project the uvOffset
                    float3 normal = normalize(uvOffset - cameraOrigin);
                    
                    float dotProd = dot(normalize(uvOffset), coneDir);

                    if (dotProd < cosTheta)
                    {
                        if (dotProdCamera < cosTheta)
                            return float4(1, 0, 0, 0);

                        continue;
                    }

                    float2 angle = GetAngle(normal);
                    float2 uv = GetUV(angle, eyeIndex);
                    float sampledHeight = _DepthScale / tex2D(_DepthTex, uv).r;
                                        
                    if (sampledHeight <= currentLayerHeight)
                    {
                        if (abs(sampledHeight - currentLayerHeight) > 0.005){
                            if (first)
                                return float4(0, 1, 1, 0);
                                
                            return tex2Dlod(_MainTex, float4(uv, 0, 6));
                        }

                        // return float4(j / (float)numSteps, 0, 0, 1);
                        return float4(tex2D(_MainTex, uv).rgb, GetFade(uvOffset, coneDir, cosTheta));
                    }

                    first = false;
                }

                float3 dir = normalize(distPosition);
                float2 uv = GetUV(GetAngle(dir), eyeIndex);
                
                if (first || dotProdCamera < cosTheta)
                    return float4(0, 1, 0, 0);

                // return float4(1, 0, 0, 1);
                return float4(tex2D(_MainTex, uv).rgb, GetFade(uvOffset, coneDir, cosTheta));
            }

            ENDCG
        }
    }
}
