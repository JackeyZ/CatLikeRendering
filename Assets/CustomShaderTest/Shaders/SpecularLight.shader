Shader "Custom/SpecularLight"  // 镜面反射
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)                    // 漫反射颜色（反射率）
        _MainTex ("Texture", 2D) = "white" {}
        _Smoothness("Smoothness", Range(0, 1)) = 0.5
        _SpecularTint("Specular", Color) = (0.5, 0.5, 0.5)      // 高光反射颜色（反射率）
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
            float _Smoothness;
            float3 _SpecularTint;

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
                float3 lightDir = _WorldSpaceLightPos0.xyz;                             // 光照方向， 从当前片元指向光源
                float3 lightColor = _LightColor0.rgb;

                // 漫反射
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;                  // 漫反射反射率
                float oneMinusReflectivity;
                // 确保漫反射的材质反射率加上高光反射的反射率不超过1
                float albedo_energy = EnergyConservationBetweenDiffuseAndSpecular(albedo, _SpecularTint.rgb, oneMinusReflectivity);       // 镜面反射工作流
                float3 diffuseLight = DotClamped(lightDir, i.normal) * lightColor;      // 漫反射光，DotClamped：点乘，并限制到0~1，光照方向和法线的夹角越小，漫反射越强
                float3 diffuse = albedo_energy * diffuseLight;                          // 漫反射最终颜色

                // 镜面反射
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);                              // 摄像机方向
                float3 reflectionDir = reflect(-lightDir, i.normal);                                        // 反射光方向
                float3 reflectionLight = DotClamped(viewDir, reflectionDir);                                // 镜面反射光强度，反射方向与视线方向夹角越小，光强度越大
                float3 specular = _SpecularTint.rgb * lightColor * pow(reflectionLight, _Smoothness * 100); // 镜面反射最终颜色

                fixed4 col = tex2D(_MainTex, i.uv);
                return  float4(diffuse + specular, 1);
            }
            ENDCG
        }
    }
}
