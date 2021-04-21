// “Mate”Pass里用到，用来支持静态光照贴图和动态光照贴图
#if !defined(CUSTOM_LIGHTMAPPING_INLCUDE)
#define CUSTOM_LIGHTMAPPING_INLCUDE

// 导入光照输入脚本
#include "CustomLightingInput.cginc"        
#include "UnityMetaPass.cginc"           

// 定义获取反射率的方法
#if !defined(ALBEDO_FUNCTION)
    #define ALBEDO_FUNCTION GetAlbedo
#endif

// 顶点着色器
// meta pass里VertexData各变量含义
// vertex    顶点的光照贴图纹理映射坐标
// uv        模型顶点上的uv
// uv1       顶点上对应静态光照贴图的uv（LIGHTMAP_ON关键字启用的时候有效）
// uv2       顶点上对应动态光照贴图的uv (勾选Lighting -> Realtime Lighting -> Realtime Global Illumination有效)
Interpolators MyLightmappingVertexProgram(VertexData v) 
{
    Interpolators i;
    //v.vertex.xy = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;    // 对光照贴图uv进行缩放和偏移
    //v.vertex.z = v.vertex.z > 0 ? 0.0001 : 0;
    //i.pos = UnityObjectToClipPos(v.vertex);                             // uv转换到裁剪空间

    // 根据顶点的光照贴图纹理映射坐标，求得顶点在模型空间中的x、y值，然后变换到裁剪空间中并返回
    i.pos = UnityMetaVertexPosition(v.vertex, v.uv1, v.uv2, unity_LightmapST, unity_DynamicLightmapST);

    // 在需要的时候才计算世界空间法线
    #if defined(META_PASS_NEEDS_NORMALS)
        i.normal = UnityObjectToWorldNormal(v.normal);
    #else
        i.normal = float3(0, 1, 0);
    #endif
    
    // 在需要的时候才计算世界坐标
    #if defined(META_PASS_NEEDS_POSITION)
        i.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
    #else
        i.worldPos.xyz = 0;
    #endif

    // 拥有有效默认uv的时候才把uv传过去
    #if !defined(NO_DEFAULT_UV)
        // 对uv进行缩放和偏移，便于片元函数对贴图采样
        i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
        i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    #endif

    return i;
}

half4 MyLightmappingFragmentProgram(Interpolators i) : SV_target
{
    SurfaceData surface;
    surface.normal = normalize(i.normal);       // 世界空间法线
    surface.albedo = 1;                     
    surface.alpha = 1;
    surface.emission = 0;
    surface.metallic = 0;
    surface.occlusion = 1;
    surface.smoothness = 0.5;
    // 判断是否定义了表面函数
    #if defined(SURFACE_FUNCTION)
        SurfaceParameters sp;
        sp.normal = i.normal;
        sp.position = i.worldPos.xyz;
        sp.uv = UV_FUNCTION(i);
        SURFACE_FUNCTION(surface, sp);
    #else
        // 给静态光照贴图或动态光照贴图的间接光信息里，只需要提供这四个属性
        surface.albedo = ALBEDO_FUNCTION(i);
        surface.emission = GetEmission(i);
        surface.metallic = GetMetallic(i);
        surface.smoothness = GetSmoothness(i);
    #endif

    UnityMetaInput surfaceData;
    surfaceData.Emission = surface.emission;
    float oneMinusReflectivity;
    surfaceData.Albedo = DiffuseAndSpecularFromMetallic(surface.albedo, surface.metallic, surfaceData.SpecularColor, oneMinusReflectivity);     // 金属工作流，得到漫反射和高光反射颜色
    
    // 非金属应该产生更多间接光，越粗糙则越应该把高光反射的亮度叠加到漫反射上
    float roughness = SmoothnessToRoughness(surface.smoothness) * 0.5;                    // 平滑度转换成粗糙度，非线性转换，更真实
    surfaceData.Albedo += surfaceData.SpecularColor * roughness;                        // 越粗糙，越把高光反射的亮度叠加到漫反射上

    return UnityMetaFragment(surfaceData);                                              // 计算最后的颜色，输入参数只有漫反射和自发光有用到
}
#endif