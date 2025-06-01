Shader "Unlit/infill shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DepthTex ("Texture", 2D) = "white" {}
        _SizeX ("_SizeX", Float) = 0.0
        _SizeY ("_SizeY", Float) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _DepthTex;
            float4 _MainTex_ST;

            float _SizeX;
            float _SizeY;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float2 texelSize = float2(_SizeX, -_SizeY);
                                
                float d0 = tex2D(_DepthTex, uv + float2(0,                      0) + float2(-_SizeX / 4, _SizeY / 4)).r;
                float d1 = tex2D(_DepthTex, uv + float2(0,            texelSize.y) + float2(-_SizeX / 4, _SizeY / 4)).r;
                float d2 = tex2D(_DepthTex, uv + float2(texelSize.x,            0) + float2(-_SizeX / 4, _SizeY / 4)).r;
                float d3 = tex2D(_DepthTex, uv + float2(texelSize.x,  texelSize.y) + float2(-_SizeX / 4, _SizeY / 4)).r;

                float diffX = (d0 + d1) / 2 - (d2 + d3) / 2;
                float diffY = (d0 + d2) / 2 - (d1 + d3) / 2;
                float2 diff = -float2(diffX, diffY) / ((d0 + d1 + d2 + d3) / 4);
                
                float lengthSq = dot(diff, diff);
                diff = lengthSq > 0.001 ? normalize(diff) * 2 : diff;
                
                return tex2D(_MainTex, uv + diff * texelSize);

                // Sample a 2x2 region and average
                float4 c0 = tex2D(_MainTex, uv + float2(0,                      0) + float2(-_SizeX / 4, _SizeY / 4) + diff * texelSize);
                float4 c1 = tex2D(_MainTex, uv + float2(0,            texelSize.y) + float2(-_SizeX / 4, _SizeY / 4) + diff * texelSize);
                float4 c2 = tex2D(_MainTex, uv + float2(texelSize.x,            0) + float2(-_SizeX / 4, _SizeY / 4) + diff * texelSize);
                float4 c3 = tex2D(_MainTex, uv + float2(texelSize.x,  texelSize.y) + float2(-_SizeX / 4, _SizeY / 4) + diff * texelSize);
                return (c0 + c1 + c2 + c3) * 0.25;
            }
            ENDCG
        }
    }
}
