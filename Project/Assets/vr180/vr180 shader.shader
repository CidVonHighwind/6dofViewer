Shader "Unlit/vr180 shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Angle ("Angle", Range(-0.25, 0.25)) = 0
        _Eye ("Eye", Range(0, 1)) = 0
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
                float3 spherePosition : TEXCOORD2;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            float _Angle = 0.0;
            int _Eye = 0;

            v2f vert (appdata v)
            {
                v2f o;
                
                UNITY_SETUP_INSTANCE_ID(v); // VR
                UNITY_INITIALIZE_OUTPUT(v2f, o); // VR
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); // VR

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.spherePosition = v.vertex.xyz;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);                             // VR
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);            // VR

                int eyeIndex = _Eye;// unity_StereoEyeIndex;
                
                float coneAngle = 65;
                float cosTheta = cos(radians(coneAngle));
                float3 coneDir = float3(0, 0, 1);
                float dotProdCamera = dot(normalize(i.spherePosition), coneDir);
                
                if (dotProdCamera < cosTheta)
                    return float4(1, 0, 0, 0);

                //if (eyeIndex != _Eye)
                //    discard;

                float3 dir = normalize(i.spherePosition);               // your normalized vector

                float theta = atan2(dir.x, dir.z) + _Angle * eyeIndex;  // horizontal angle
                float phi = asin(dir.y);                                // vertical angle

                float u = theta / PI + 0.5;
                float v = phi / (PI) + 0.5;

                float2 uv = float2(theta / PI / 2 + 0.25, phi / (PI) + 0.5);

                if (i.spherePosition.z < 0)
                    return float4(0, 0, 0, 0);
                
                if (eyeIndex == 1)
                    uv.x += 0.5;

                 return tex2D(_MainTex, uv);
            }
            ENDCG
        }
    }
}
