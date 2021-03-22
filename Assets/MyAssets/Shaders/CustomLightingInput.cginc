// 
// 本脚本存放CustomLighting里用到的所有结构体、变量和Get函数
//
#if !defined(CUSTOM_LIGHTING_INPUT_INLCUDE)
#define CUSTOM_LIGHTING_INPUT_INLCUDE

// 如果获取反射率的方法没有被其他地方定义，则定义GetAlbedo作为获取反射率的方法（方便其他地方重写该方法）
#if !defined(ALBEDO_FUNCTION)
    #define ALBEDO_FUNCTION GetAlbedo
#endif

// UnityPBSLighting需要放到AutoLight之前
#include "UnityPBSLighting.cginc"           
#include "AutoLight.cginc"

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #if !defined(FOG_DISTANCE)
        #define FOG_DEPTH 1
    #endif
    #define FOG_ON 1
#endif
 
// 表明VertexData里有切线、uv1、uv2，在细分着色器中的需要用到
#define TESSELLATION_TANGENT 1
#define TESSELLATION_UV1 1
#define TESSELLATION_UV2 1

#if defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
    #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK)
        // 表明现在是混合光模式的削减模式（Subtractive Mod）下的静态物体, 动态物体不会定义LIGHTMAP_ON
        #define SUBTRACTIVE_LIGHT 1 
    #endif
#endif


// 如果使用视差贴图，且启用顶点偏移
#if defined(_PARALLAX_MAP) && defined(VERTEX_DISPLACEMENT_INSTEAD_OF_PARALLAX)
    // 取消使用uv的视差偏移
    #undef _PARALLAX_MAP               
    // 启用顶点偏移
    #define VERTEX_DISPLACEMENT 1       
    // 给视差贴图的变量弄个新别名，在细分着色器里用
    #define _DisplacementMap _ParallaxMap
    // 给视差强度弄个新别名，在细分着色器里用
    #define _DisplacementStrength _ParallaxStrength
#endif

// 顶点函数输入
struct VertexData
{
    UNITY_VERTEX_INPUT_INSTANCE_ID                      // 实例ID , 是一个uint，不同平台语义会不同，具体看源码，支持GPUInstance 
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;                             // 静态光照贴图uv（LIGHTMAP_ON关键字启用的时候有效）
    float2 uv2 : TEXCOORD2;                             // 动态光照贴图uv（DYNAMICLIGHTMAP_ON关键字启用的时候有效）
};

// 顶点函数输出
struct InterpolatorsVertex
{
    UNITY_VERTEX_INPUT_INSTANCE_ID                      // 实例ID , 是一个uint，不同平台语义会不同，具体看源码，支持GPUInstance 
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;                          // 世界空间法线

    // 判断是否用片元函数计算副法线
    #if defined(BINORMAL_PER_FRAGMENT)
        float4 tangent : TEXCOORD2;
    // 如果不用片元函数计算，则在顶点函数算好副法线插值传过来
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif

    // 如果定义了深度雾
    #if FOG_DEPTH
        float4 worldPos : TEXCOORD4;
    #else
        float3 worldPos : TEXCOORD4;
    #endif
    float4 pos : SV_POSITION;                         // 裁剪坐标，写死名称为pos配合TRANSFER_SHADOW使用

    // 判断是否开启了阴影接收
    //#if defined(SHADOWS_SCREEN)
    //    float4 shadowCoordinates : TEXCOORD5;       // 阴影贴图uv坐标
    //#endif
    // 定义阴影贴图uv坐标，传入5表示放在TEXCOORD5
    //SHADOW_COORDS(5)
    // 定义阴影贴图uv坐标，传入5表示放在TEXCOORD5
	UNITY_SHADOW_COORDS(5)

    // 判断是否开启了顶点光源
    #if defined(VERTEXLIGHT_ON) 
        float3 vertexLightColor : TEXCOORD6;
    #endif

    // 判断是否使用静态光照贴图
    #if defined(LIGHTMAP_ON) 
        float2 lightmapUV : TEXCOORD6;                 // 光照贴图uv，与顶点光照互斥，所以这里也使用TEXCOORD6
    #endif

    // 判断是否启用了动态光照贴图                      // 勾选Lighting -> Realtime Lighting -> Realtime Global Illumination有效
    #if defined(DYNAMICLIGHTMAP_ON)
        float2 dynamicLightmapUV : TEXCOORD7;
    #endif

    #if defined(_PARALLAX_MAP)
        float3 tangentViewDir : TEXCOORD8;               // 用来储存切线空间下的视线方向（片元指向摄像机的向量）
    #endif
};

// 片元函数输入
struct Interpolators
{
    UNITY_VERTEX_INPUT_INSTANCE_ID                      // 实例ID , 是一个uint，不同平台语义会不同，具体看源码，支持GPUInstance 
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;                          // 世界空间法线

    // 判断是否用片元函数计算副法线
    #if defined(BINORMAL_PER_FRAGMENT)
        float4 tangent : TEXCOORD2;
    // 如果不用片元函数计算，则在顶点函数算好副法线插值传过来
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif

    // 如果定义了深度雾
    #if FOG_DEPTH
        float4 worldPos : TEXCOORD4;
    #else
        float3 worldPos : TEXCOORD4;
    #endif

    // 判断是否启用了LOD淡入淡出
    #if defined(LOD_FADE_CROSSFADE)
        UNITY_VPOS_TYPE vpos : VPOS;                      // 屏幕空间坐标(x ∈ [0, width]， y ∈ [0, height])，作为片元着色器输入的时候与下面SV_POSITION是一样的，都是屏幕空间坐标,  UNITY_VPOS_TYPE：相当于float4, DX9是float2
    #else
        float4 pos : SV_POSITION;                         // 作为顶点着色器输出的时候是裁剪坐标，写死名称为pos配合TRANSFER_SHADOW使用，作为片元着色器输入的时候是屏幕坐标，但是做了0.5的偏移以选中像素中心
    #endif

    // 判断是否开启了阴影接收
    //#if defined(SHADOWS_SCREEN)
    //    float4 shadowCoordinates : TEXCOORD5;       // 阴影贴图uv坐标
    //#endif
    // 定义阴影贴图uv坐标，传入5表示放在TEXCOORD5
    //SHADOW_COORDS(5)
    // 定义阴影贴图uv坐标，传入5表示放在TEXCOORD5
	UNITY_SHADOW_COORDS(5)

    // 判断是否开启了顶点光源
    #if defined(VERTEXLIGHT_ON) 
        float3 vertexLightColor : TEXCOORD6;
    #endif

    // 判断是否使用静态光照贴图
    #if defined(LIGHTMAP_ON) 
        float2 lightmapUV : TEXCOORD6;                 // 光照贴图uv，与顶点光照互斥，所以这里也使用TEXCOORD6
    #endif

    // 判断是否启用了动态光照贴图                      // 勾选Lighting -> Realtime Lighting -> Realtime Global Illumination有效
    #if defined(DYNAMICLIGHTMAP_ON)
        float2 dynamicLightmapUV : TEXCOORD7;
    #endif

    #if defined(_PARALLAX_MAP)
        float3 tangentViewDir : TEXCOORD8;              // 切线空间下的视线方向（片元指向摄像机的向量）
    #endif

    // 判断是否有几何着色器传过来的数据
    #if defined(CUSTOM_GEOMETRY_INTERPOLATORS)
        CUSTOM_GEOMETRY_INTERPOLATORS                   // 通过宏获取几何着色器传过来的插值器数据
    #endif
};

// 片元函数返回结构体
struct FragmentOutPut{
    #if defined(DEFERRED_PASS)
        float4 gBuffer0 : SV_TARGET0;
        float4 gBuffer1 : SV_TARGET1;
        float4 gBuffer2 : SV_TARGET2;
        float4 gBuffer3 : SV_TARGET3;
		// 判断是否启用了阴影遮罩
		// 判断平台是否支持大于4个gBuffer
		#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
			float4 gBuffer4 : SV_TARGET4;
		#endif
    #else
        float4 color : SV_Target;
    #endif
};

// 创建属性缓冲区(在启用GPUInstance的时候，放在缓冲区的属性仅需一次SetPassCalls（修改材质渲染状态）就可以一次性设置所有对象的属性，以instance id为索引放进缓冲里)
UNITY_INSTANCING_BUFFER_START(InstanceProperties)   
    // 相当于float4 _Color，但不同平台有些许不同，这里用宏处理
    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
    // 定义颜色buffer数组，储存外部传进来的属性块，令颜色属性拥有缓冲区
    #define _Color_arr InstanceProperties
UNITY_INSTANCING_BUFFER_END(InstanceProperties)

sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;
float _Cutoff;                                  // 透明度裁剪阈值

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;             // 法线凹凸感缩放

sampler2D _MetallicMap;                         // 金属度贴图
float _Metallic;                                // 金属度
float _Smoothness;                              // 粗糙度

sampler2D _ParallaxMap;                         // 视差贴图
float _ParallaxStrength;                        // 视差强度

sampler2D _OcclusionMap;                        // 自阴影贴图
float _OcclusionStrength;                       // 自阴影强度

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

// 获得自阴影
float GetOcclusion(Interpolators i){
    #if defined(_OCCLUSION_MAP)
        return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);  // 自阴影强度是0的时候返回1，表示不影响正常光照，当前强度是1的时候则返回自阴影贴图的数值
    #else
        return 1;
    #endif
}

// 获得自发光颜色
float3 GetEmission(Interpolators i){
    // 前向渲染的基础pass和延迟渲染的pass使用
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        #if defined(_EMISSION_MAP)
            return tex2D(_EmissionMap, i.uv.xy) * _Emission;
        #else
            return _Emission;
        #endif
    #else
        return 0;
    #endif
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
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).rgb;
    #if defined(_DETAIL_ALBEDO_MAP)
        float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * details, GetDetailMask(i));
    #endif
    return albedo;
}

// 获得透明度
float GetAlpha(Interpolators i){
    float alpha = UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a;
    // 如果粗糙度来源不是主纹理的a通道
    #if !defined(_SMOOTHNESS_ALBEDO)
        alpha = UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a * tex2D(_MainTex, i.uv.xy).a;
    #endif
    return alpha;
}

// 获取切线空间的法线
float3 GetTangentSpaceNormal(Interpolators i){
    float3 normal = float3(0, 0, 1);

    #if defined(_NORMAL_MAP)
        normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);                              // 主法线贴图，根据平台自动对方法线贴图使用正确的解码，并缩放法线
    #endif
    
    #if defined(_DETAIL_NORMAL_MAP)
        float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);                // 细节法线贴图， 根据平台自动对方法线贴图使用正确的解码，并缩放法线
        detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));                                       // 配合细节贴图遮罩
        normal = BlendNormals(normal, detailNormal);                                                                // 融合法线
    #endif

    return normal;
}

// 采样并返回视差贴图
float GetParallaxHeight(float2 uv)
{
    return tex2D(_ParallaxMap, uv).g;
}

#endif