Shader "Unlit/downsample shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DepthTex ("Texture", 2D) = "white" {}
        _SizeX ("Texture", Float) = 0.0
        _SizeY ("Texture", Float) = 0.0
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
                float2 uv = i.uv - float2(_SizeX / 4, -_SizeY / 4);
                float2 texelSize = float2(_SizeX, _SizeY);
                
                // no idea what the fuck is going on with the offset
                float4 c0 = tex2D(_MainTex, uv + float2(0,                      0));
                float4 c1 = tex2D(_MainTex, uv + float2(0,            texelSize.y));
                float4 c2 = tex2D(_MainTex, uv + float2(texelSize.x,            0));
                float4 c3 = tex2D(_MainTex, uv + float2(texelSize.x,  texelSize.y));

                return (c0 + c1 + c2 + c3) * 0.25;
            }
            ENDCG
        }
    }
}
