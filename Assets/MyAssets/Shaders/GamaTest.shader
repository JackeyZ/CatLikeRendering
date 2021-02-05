Shader "Custom/GamaTest"  // 镜面反射
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MainTex_2 ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //#include "UnityCG.cginc"
            #include "UnityStandardBRDF.cginc"
            #include "UnityStandardUtils.cginc"

            // 顶点函数输入
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            // 片元函数输入
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos :TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            float3 _Tint;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _MainTex_2;
            float4 _MainTex_2_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);             // 裁剪坐标
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);       // 世界坐标
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);                  // uv
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 color1 = tex2D(_MainTex, i.uv);
                float4 color2 = tex2D(_MainTex_2, i.uv);
                return  color1 * color2;
            }
            ENDCG
        }
    }
}
