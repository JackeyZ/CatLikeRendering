#if !defined(CUSTOM_LIGHTMAPPING_INLCUDE)
#define CUSTOM_LIGHTMAPPING_INLCUDE

#include "UnityPBSLighting.cginc"        
#include "UnityMetaPass.cginc"           

// 顶点函数输入
struct appdata
{
    float4 vertex : POSITION;                           // 顶点的光照贴图纹理映射坐标
    float2 uv : TEXCOORD0;                              // 模型顶点上的uv
    float2 uv1 : TEXCOORD1;                             // 顶点上对应静态光照贴图的uv（LIGHTMAP_ON关键字启用的时候有效）
    float2 uv2 : TEXCOORD2;                             // 顶点上对应动态光照贴图的uv (勾选Lighting -> Realtime Lighting -> Realtime Global Illumination有效)
};

// 片元函数输入
struct Interpolators
{
    float4 pos : SV_POSITION;                           // 裁剪坐标，写死名称为pos配合TRANSFER_SHADOW使用
    float4 uv : TEXCOORD0;
};

float4 _Color;
sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;

sampler2D _MetallicMap;                         // 金属度贴图
float _Metallic;                                // 金属度
float _Smoothness;                              // 粗糙度

sampler2D _EmissionMap;                         // 自发光贴图
float3 _Emission;                               // 自发光颜色


// 对金属度贴图进行采样，获得金属度（r通道）
float GetMetallic(Interpolators i){
    #if defined(_METALLIC_MAP)
        return tex2D(_MetallicMap, i.uv.xy).r * _Metallic;
    #else
        return _Metallic;
    #endif
}

// 获得粗糙度
float GetSmoothness(Interpolators i){
    float smoothness = 1;
    #if defined(_SMOOTHNESS_ALBEDO)
        smoothness = tex2D(_MainTex, i.uv.xy).a;
    #elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
        smoothness = tex2D(_MetallicMap, i.uv.xy).a;
    #endif
    return smoothness * _Smoothness;
}


// 获得细节贴图遮罩
float GetDetailMask(Interpolators i){
    #if defined(_DETAIL_MASK)
        return tex2D(_DetailMask, i.uv.xy).a;
    #else
        return 1;
    #endif
}

// 获得漫反射固有色
float3 GetAlbedo(Interpolators i){
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
    #if defined(_DETAIL_ALBEDO_MAP)
        float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * details, GetDetailMask(i));
    #endif
    return albedo;
}

// 获得自发光颜色
float3 GetEmission(Interpolators i){
    #if defined(_EMISSION_MAP)
        return tex2D(_EmissionMap, i.uv.xy) * _Emission;
    #else
        return _Emission;
    #endif
}

Interpolators MyLightmappingVertexProgram(appdata v)
{
    Interpolators i;
    //v.vertex.xy = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;    // 对光照贴图uv进行缩放和偏移
    //v.vertex.z = v.vertex.z > 0 ? 0.0001 : 0;
    //i.pos = UnityObjectToClipPos(v.vertex);                             // uv转换到裁剪空间

    // 根据顶点的光照贴图纹理映射坐标，求得顶点在模型空间中的x、y值，然后变换到裁剪空间中并返回
    i.pos = UnityMetaVertexPosition(v.vertex, v.uv1, v.uv2, unity_LightmapST, unity_DynamicLightmapST);

    // 对uv进行缩放和偏移，便于片元函数对贴图采样
    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);

    return i;
}

half4 MyLightmappingFragmentProgram(Interpolators i) : SV_target
{
    UnityMetaInput surfaceData;
    surfaceData.Emission = GetEmission(i);
    float oneMinusReflectivity;
    surfaceData.Albedo = DiffuseAndSpecularFromMetallic(GetAlbedo(i), GetMetallic(i), surfaceData.SpecularColor, oneMinusReflectivity);     // 金属工作流，得到漫反射和高光反射颜色
    
    // 非金属应该产生更多间接光，越粗糙则越应该把高光反射的亮度叠加到漫反射上
    float roughness = SmoothnessToRoughness(GetSmoothness(i)) * 0.5;            // 平滑度转换成粗糙度，非线性转换，更真实
    surfaceData.Albedo += surfaceData.SpecularColor * roughness;                // 越粗糙，越把高光反射的亮度叠加到漫反射上

    return UnityMetaFragment(surfaceData);                                      // 计算最后的颜色，输入参数只有漫反射和自发光有用到
}
#endif