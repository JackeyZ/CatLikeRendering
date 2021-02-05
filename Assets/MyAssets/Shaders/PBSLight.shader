Shader "Custom/PBSLight"
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)                    // 漫反射反射颜色
        _MainTex ("Texture", 2D) = "white" {}
        _Smoothness("Smoothness", Range(0, 1)) = 0.5
        _Metallic("Metallic", Range(0, 1)) = 0                  // 金属度
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
            // 用3.0，确保PBS达到最好的效果
            #pragma target 3.0             
            #pragma vertex vert
            #pragma fragment frag

            //#include "UnityCG.cginc"
            //#include "UnityStandardBRDF.cginc"
            //#include "UnityStandardUtils.cginc"
            #include "UnityPBSLighting.cginc"

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
            float _Smoothness;
            float _Metallic;
            //float3 _SpecularTint;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);             // 裁剪坐标
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);       // 世界坐标
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);                  // uv
                o.normal = UnityObjectToWorldNormal(v.normal);         // 法线世界坐标
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                i.normal = normalize(i.normal);
                float3 lightDir = _WorldSpaceLightPos0.xyz;                                                         // 光照方向， 从当前片元指向光源
                float3 lightColor = _LightColor0.rgb;
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);                                      // 摄像机方向
                float3 _SpecularTint;

                // 漫反射
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;                                              // 漫反射反射率
                float oneMinusReflectivity;
                // 确保漫反射的材质反射率加上高光反射的反射率不超过1，并得出高光反射的反射率
                albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, _SpecularTint, oneMinusReflectivity);     // 金属工作流


                // 光照数据结构体
                UnityLight light;
                light.color = lightColor;                           // 光照颜色
                light.dir = lightDir;                               // 光照方向
                light.ndotl = DotClamped(i.normal, lightDir);       // 漫反射强度    

                // 间接光数据结构体
                UnityIndirect indirectLight;
                indirectLight.diffuse = 0;
                indirectLight.specular = 0;

                return  UNITY_BRDF_PBS(albedo, _SpecularTint,                   // 漫反射颜色，高光反射颜色
                                        oneMinusReflectivity, _Smoothness,      // 1 - 反射率，粗糙度
                                        i.normal, viewDir,                      // 世界空间下的法线和摄像机方向
                                        light, indirectLight);                  // 光照数据, 间接光数据
            }
            ENDCG
        }
    }
}
