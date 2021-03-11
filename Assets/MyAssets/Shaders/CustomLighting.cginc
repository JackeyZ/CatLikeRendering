#if !defined(CUSTOM_LIGHTING_INLCUDE)
#define CUSTOM_LIGHTING_INLCUDE

// UnityPBSLighting需要放到AutoLight之前
#include "UnityPBSLighting.cginc"           
#include "AutoLight.cginc"

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #if !defined(FOG_DISTANCE)
        #define FOG_DEPTH 1
    #endif
    #define FOG_ON 1
#endif
 
#if defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
    #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK)
        // 表明现在是混合光模式的削减模式（Subtractive Mod）下的静态物体, 动态物体不会定义LIGHTMAP_ON
        #define SUBTRACTIVE_LIGHT 1 
    #endif
#endif

// 顶点函数输入
struct appdata
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

// 阴影距离渐变衰减（阴影距离的设置对应: Project Setting -> Quality -> Shadow Distance）
// attenuation是光照衰减，已和阴影贴图采样得到的阴影值融合
float FadeShadows(Interpolators i, float attenuation) {
	// UNITY_LIGHT_ATTENUATION宏里对定义里HANDLE_SHADOWS_BLENDING_IN_GI关键字的情况，对阴影没有做距离渐变衰减，这里自行计算
	// HANDLE_SHADOWS_BLENDING_IN_GI何时定义？混合光状态下当mesh与摄像机距离小于阴影距离的时候定义。
	#if HANDLE_SHADOWS_BLENDING_IN_GI
		float viewZ = dot(_WorldSpaceCameraPos - i.worldPos, UNITY_MATRIX_V[2].xyz);	// 世界空间转换到视口空间，取得z值，但这个z是正值，由于只需要z值，所以用UNITY_MATRIX_V[2]足够了
		float shadowFadeDistance = UnityComputeShadowFadeDistance(i.worldPos, viewZ);   // 得到片元与阴影区域中心（衰减中心）的距离
		float shadowFade = UnityComputeShadowFade(shadowFadeDistance);                  // 根据片元到衰减中心的距离计算阴影衰减值,0~1，0表示阴影不衰减，1表示全衰减（没有阴影）
		float bakedAttenuation = UnitySampleBakedOcclusion(i.lightmapUV, i.worldPos);	// 读取烘焙的阴影遮罩(即静态阴影贴图,烘焙需选中Window->Lighting Settings->Mixed Lighting->Lighting Mode->Shadowmask)，mesh如果在阴影距离外会自动读取
		//attenuation = saturate(attenuation + shadowFade);								// 把阴影衰减叠加到衰减值上
		attenuation = UnityMixRealtimeAndBakedShadows(attenuation, bakedAttenuation, shadowFade);// 把阴影衰减和阴影遮罩的值叠加到光照衰减值上
	#endif
	return attenuation;
}

UnityLight CreateLight(Interpolators i){
    // 光照数据结构体
    UnityLight light;
    // 延迟渲染下不需要提前在此计算直接光，光照会在DeferredShading里计算，在CustomDefferedShading里的CreateLight方法计算直接光
    // 混合光照的削减模式下静态物体不需要计算直接光，直接光从lightmap中获取
    #if defined(DEFERRED_PASS) || defined(SUBTRACTIVE_LIGHT)
        light.dir = float3(0, 1, 0);
        light.color = 0;
    #else
        float3 lightDir = _WorldSpaceLightPos0.xyz;
        #if defined (POINT) || defined(SPOT) || defined(POINT_COOKIE)
        lightDir = _WorldSpaceLightPos0.xyz - i.worldPos.xyz;           // _WorldSpaceLightPos0：定向光表示光照方向， 点光源则表示光源位置 
        #endif
        light.dir = normalize(lightDir); 

        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);        // 调用unity内置的衰减方法，对阴影贴图的采样也在这里面，第二个参数就是用来算阴影的
		attenuation = FadeShadows(i, attenuation);                      // 按需进行阴影衰减计算和阴影遮罩采样
		attenuation *= GetOcclusion(i);
        light.color = _LightColor0.rgb * attenuation;                   // 光照颜色
    #endif

    return light;
}

// 处理顶点光源(非重要光)
void ComputeVertexLightColor(inout Interpolators i){
    #if defined(VERTEXLIGHT_ON)
        // 最多支持四个顶点光源
        i.vertexLightColor = Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,        // 传入四个顶点光源的位置
            unity_LightColor[0].rgb, unity_LightColor[1].rgb,               // 四个光源的颜色
            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0,                                             // 四个顶点光源光照衰减因子
            i.worldPos.xyz, i.normal                        
        );
    #endif
}

// 创建副法线
float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign){
    return cross(normal, tangent.xyz) * (binormalSign * unity_WorldTransformParams.w);  // unity_WorldTransformParams的w存储着副法线是否需要翻转（例如当scale的x是-1的时候，我们就需要翻转副法线）
}

// direction 摄像机到片元的射线的反射光
// position：片元世界坐标
// cubemapPosition 反射探头坐标
// boxMin    反射探头包围盒最小点
// boxMax    反射探头包围盒最大点
float3 BoxProjection(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax){
    // 判断目标平台是否支持盒型探头
	#if UNITY_SPECCUBE_BOX_PROJECTION
        // 如果是包围盒(对应反射探头组件里面的Box Projection)
        UNITY_BRANCH                                                                                    // 表示先执行if语句再执行语句内部逻辑
        if(cubemapPosition.w > 0)
        {
            float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;                // swizzle操作, 其实是xyz分开计算的
            float scalar = min(min(factors.x, factors.y), factors.z);                                   // 取最小值，看下片元更靠近包围盒的哪个面，后面direction乘以scalar缩放后, direction末端点就恰好落在包围盒的表面上
            return direction * scalar + (position - cubemapPosition);
        }
	#endif
    return direction;
}

// 混合光照下的削减模式下对从LightMap中读取到的光照进行削减
void ApplySubtractiveLighting(Interpolators i, inout UnityIndirect indirectLight)
{
    // 判断当前是否在混合光的削减模式下（静态物体），该模式下静态光照贴图里包含了间接光、直接光和静态阴影，混合光下的其他模式的光照贴图只包含间接光
    #if SUBTRACTIVE_LIGHT
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz)             // 得到光照衰减（已根据情况融合动态阴影（shadowmap））
        attenuation = FadeShadows(i, attenuation);                          // 融合阴影遮罩（静态阴影）和阴影距离衰减

        float ndotl = saturate(dot(i.normal, _WorldSpaceLightPos0.xyz));    // 平行光情况下_WorldSpaceLightPos0表示光照方向，这里用lambert光照模型求得漫反射强度（0~1）
        // attenuation如果是1表示光照没有衰减（没有动态阴影)
        float3 shadowedLightEstimate = ndotl * (1 - attenuation) * _LightColor0.rgb;        // 这里计算得到光照衰减了多少
        float3 subtractedLight = indirectLight.diffuse - shadowedLightEstimate;             // 用静态光照贴图中的值减去衰减了的光照得到衰减后的光照（所谓的削减模式）
        subtractedLight = max(subtractedLight, unity_ShadowColor.rgb);                      // 避免阴影过于黑暗，设一个下限（unity_ShadowColor对应设置Lighting->Mixed Lighting->Realtime Shadow Color）
        subtractedLight = lerp(subtractedLight, indirectLight.diffuse, _LightShadowData.x); //  _LightShadowData.x是(1-阴影强度)对应灯光组件里面的strength,当阴影强度是0的时候就取indirectLight.diffuse（lightmap里的值）
        indirectLight.diffuse = min(subtractedLight, indirectLight.diffuse);                // 当削减后的值比lightmap的值还要亮的时候，取lightmap的，避免动态阴影与静态阴影重叠的时候取了一个较亮的值
    #endif
}

// 创建间接光
UnityIndirect CreateIndirectLight(Interpolators i, float3 viewDir){
    // 间接光数据结构体
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0; 
    indirectLight.specular = 0;

    // 判断是否启用了顶点光
    #if defined(VERTEXLIGHT_ON) 
        indirectLight.diffuse = i.vertexLightColor;
    #endif
    
    // base pass才进行环境光的计算
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        // 是否启用静态光照贴图
        #if defined(LIGHTMAP_ON)
            indirectLight.diffuse = DecodeLightmap( UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV) );                 // 采样光照贴图的光照，并根据不同格式进行解码
            // 是否启用静态光照方向贴图（对应面板Lighting - Lightmapping Setting - Directional Mode设置）
            #if defined(DIRLIGHTMAP_COMBINED)
                float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, i.lightmapUV); // 采样得到光照方向, 用UNITY_SAMPLE_TEX2D_SAMPLER可以复用前面对光照贴图采样的时候用的采样器
                indirectLight.diffuse = DecodeDirectionalLightmap(indirectLight.diffuse, lightmapDirection, i.normal);  // 对光照方向进行解码（半兰伯特），并叠加到diffuse上
            #endif

            // 混合光照的削减模式下调节环境光
            ApplySubtractiveLighting(i, indirectLight);
        #endif
        
        // 是否启用动态间接光贴图
        #if defined(DYNAMICLIGHTMAP_ON)
            float3 dynamicLightDiffuse = DecodeRealtimeLightmap(UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.dynamicLightmapUV));            // 采样光照贴图的光照，并根据不同格式进行解码
            // 是否启用静态光照方向贴图（对应面板Lighting - Lightmapping Setting - Directional Mode设置）
            #if defined(DIRLIGHTMAP_COMBINED)
                float4 dynamicLightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, i.dynamicLightmapUV); // 采样得到光照方向, 用UNITY_SAMPLE_TEX2D_SAMPLER可以复用前面对光照贴图采样的时候用的采样器
                indirectLight.diffuse += DecodeDirectionalLightmap(dynamicLightDiffuse, dynamicLightmapDirection, i.normal);  // 对光照方向进行解码（半兰伯特），并叠加到diffuse上
            #else
                indirectLight.diffuse += dynamicLightDiffuse;
            #endif
        #endif

        // 如果静态光照贴图和动态光照贴图都没有启用，则利用光照探头进行近似计算
        #if !defined(LIGHTMAP_ON) && !defined(DYNAMICLIGHTMAP_ON) 
            // 判断项目是否启用了LPPV（光照探测代理体）
            //（通过设置Project Setting -> Graphics -> Tier Settings -> Enable Light Probe Proxy Volume启用）
            #if UNITY_LIGHT_PROBE_PROXY_VOLUME
                // 判断当前渲染的对象是否启用了LPPV
                // 受到光照的动态物体上要用Light Probe Proxy Volume组件才能启用LPPV
               if(unity_ProbeVolumeParams.x == 1)
               {    
                    // 本质也是球谐光照（只有前两个波带L0和L1），但是在物体表面的代理体探测球之间做了插值
                    indirectLight.diffuse = SHEvalLinearL0L1_SampleProbeVolume(float4(i.normal, 1), i.worldPos);
                    // 判断是否在gamma颜色空间下
                    #if defined(UNITY_COLORSPACE_GAMMA)
                        indirectLight.diffuse = LinearToGammaSpace(indirectLight.diffuse);                  // 因为球谐数据储存在线性颜色空间中，所以这里转换一下颜色空间
                    #endif
               }
               else
               {
                    // 球谐光照（利用光照探头获取的全局数据计算一个近似值）
                    indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
               }
            #else
                // 球谐光照（利用光照探头获取的全局数据计算一个近似值）
                indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
            #endif
        #endif

        // 环境反射
        float3 reflectionDir = reflect(-viewDir, i.normal);

        Unity_GlossyEnvironmentData envData;
        envData.roughness = 1 - GetSmoothness(i);

        // unity_SpecCube0_ProbePosition是unity_SpecCube0对应的反射探头坐标, unity_SpecCube0_BoxMin则是探头包围盒的最小端点，unity_SpecCube0_BoxMax是最大端点
        // 可以用unity自带的BoxProjectedCubemapDirection代替
        envData.reflUVW = BoxProjection(reflectionDir, i.worldPos.xyz, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);

        // 判断目标平台是否支持混合
        #if UNITY_SPECCUBE_BLENDING
            float interpolator = unity_SpecCube0_BoxMin.w;// unity_SpecCube0_BoxMin.w存着反射探头的权重
            UNITY_BRANCH
            if(interpolator < 0.99999)
            {   
                envData.reflUVW = BoxProjection(reflectionDir, i.worldPos.xyz, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
                float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube0_HDR, envData);    // 环境贴图用unity_SpecCube1，但采样器用unity_SpecCube0，因为unity_SpecCube1没有采样器
         
                indirectLight.specular = lerp(probe1, probe0, interpolator); 
            }
            else
            {
                indirectLight.specular = probe0;
            }
        #else
            indirectLight.specular = probe0;
        #endif

        // 自阴影
        float occlusion = GetOcclusion(i);
        indirectLight.diffuse *= occlusion;
        indirectLight.specular *= occlusion;

        // 延迟渲染的时候，如果启用了built in的反射，则不需要我们自己采样了，当启用built-in reflection的时候UNITY_ENABLE_REFLECTION_BUFFERS的值为1
        // UNITY_ENABLE_REFLECTION_BUFFERS对应设置：ProjectSetting - Graphics - Built-in Shader Settings - Defferred Reflection
        #if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS 
            indirectLight.specular = 0;
        #endif
    #endif

    return indirectLight;
}

// 初始化片元函数的法线
void InitializeFragmentNormal(inout Interpolators i){
    float3 tangentSpaceNormal = GetTangentSpaceNormal(i);

    // 是否定义了需要在片元函数里计算副法线
    #if defined(BINORMAL_PER_FRAGMENT)
        float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);                                 // 叉乘计算副法线，切线的w存储的是-1或者1，用来表明正负方向的
    #else
        float3 binormal = i.binormal;
    #endif

    i.normal = normalize(tangentSpaceNormal.x * i.tangent +                                                     // 切线方向偏移x
                         tangentSpaceNormal.y * binormal +                                                      // 副法线方向偏移y
                         tangentSpaceNormal.z * i.normal);                                                      // 法线方向偏移z
}

// 雾效
float4 ApplyFog(float4 color, Interpolators i){
    #if FOG_ON
        float viewDistance = length(_WorldSpaceCameraPos - i.worldPos.xyz);             // 算出片元与摄像机的距离

        // 判断是否用深度来计算雾浓度
        #if FOG_DEPTH
            viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);                  // 用裁剪空间下的z值作为距离
        #endif
        UNITY_CALC_FOG_FACTOR_RAW(viewDistance);                                        // 根据距离算出雾效因子unityFogFactor
        float3 fogColor = 0;                                                            // 光源附加通道的雾颜色，用黑色
        #if defined(FORWARD_BASE_PASS)
            fogColor = unity_FogColor.rgb;                                              // base pass的雾颜色才用设置里面的， unity_FogColor是Light Setting里的雾的颜色
        #endif
        color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));                // 根据算出来的雾效因子插值得到颜色，
    #endif
    return color;
}

// 采样并返回视差贴图
float GetParallaxHeight(float2 uv)
{
    return tex2D(_ParallaxMap, uv).g;
}

// 普通的视差偏移
float2 ParallaxOffset(float2 uv, float2 viewDir){
    float height = GetParallaxHeight(uv);
    height -= 0.5;                                                                      // 0~1 转换成-0.5~0.5 让高的地方更高，矮的地方更矮
    height *= _ParallaxStrength;
    return viewDir * height;
}

// 用光追的方式计算视差偏移
// 从顶部开始沿着视线，根据步长对视差贴图进行采样，直到找到视线与视差高度图的交点
float2 ParallaxRaymarching(float2 uv, float2 viewDir){
    // 如果未定义细分多少步，则在这里定义为细分十步
    #if !defined(PARALLAX_RAYMARCHING_STEPS)
        #define PARALLAX_RAYMARCHING_STEPS 10
    #endif
    float2 uvOffset = 0;
    float stepSize = 1.0 / PARALLAX_RAYMARCHING_STEPS;                                  // 步长
    float2 uvDelta = viewDir * stepSize * _ParallaxStrength;                            // 单位步长下的uv偏移量

    float stepHeight = 1;
    float surfaceHeight = GetParallaxHeight(uv);                                        // 采样视线顶部uv（未偏移的uv）对应的高度(高度场表面高度)
    
    float2 prevUVOffset = uvOffset;                                                     // 用于记录上一次循环的uv偏移
    float prevStepHeight = stepHeight;
    float prevSurfaceHeight = surfaceHeight;

    // 因为不同片元循环的次数可能不一样，所以这里额外给定一个i < PARALLAX_RAYMARCHING_STEPS的确定条件，
    // 每个片元都会进行确定次数的循环，最后通过stepHeight > surfaceHeight这个不确定条件来取最后的值
    for(int i = 1; i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight; i++)
    {
        prevUVOffset = uvOffset;
        prevStepHeight = stepHeight;
        prevSurfaceHeight = surfaceHeight;

        uvOffset -= uvDelta;
        stepHeight -= stepSize;
        surfaceHeight = GetParallaxHeight(uv + uvOffset);                         
    }

    #if !defined(PARALLAX_RAYMARCHING_SEARCH_STEPS)
        #define PARALLAX_RAYMARCHING_SEARCH_STEPS 0
    #endif

    // 判断是否启用二分查找的方式，找寻视线与高度场的交点
    #if PARALLAX_RAYMARCHING_SEARCH_STEPS > 0
        for(int i = 0; i < PARALLAX_RAYMARCHING_SEARCH_STEPS; i++)
        {
            uvDelta *= 0.5;
            stepSize *= 0.5;

            if(stepHeight < surfaceHeight){
                uvOffset += uvDelta;
                stepHeight += stepSize;
            }
            else
            {
                uvOffset -= uvDelta;
                stepHeight -= stepSize;
            }
            surfaceHeight = GetParallaxHeight(uv + uvOffset);    
        }
    // 检查是否需要计算两个步长之间的遮挡过渡值(不找交点, 性能较好)
    #elif defined(PARALLAX_RAYMARCHING_INTERPOLATE)
        // 用上一步长和当前步长计算两步之间的过渡值
        float prevDifference = prevStepHeight - prevSurfaceHeight;
        float difference = surfaceHeight - stepHeight;
        float t = prevDifference / (prevDifference + difference);               // 相似三角形，计算两步长之间的插值t
        uvOffset = prevUVOffset - uvDelta * t;                                  // uvDelta是片元指向摄像机的向量，所以这里用负数
    #endif

    

    return uvOffset;
}

// 视差贴图
void ApplyParallax(inout Interpolators i){
    #if defined(_PARALLAX_MAP)
        i.tangentViewDir = normalize(i.tangentViewDir);
        // 是否不限制偏移值（有需要限制的时候自行定义该宏）
        #if !defined(_PARALLAX_OFFSET_LIMITING)
            #if !defined(PARALLAX_BIAS)
                // unity 也是定义 0.42
                #define PARALLAX_BIAS 0.42                                              
            #endif
            i.tangentViewDir.xy /= (i.tangentViewDir.z + PARALLAX_BIAS);               // 计算当z是1的时候xy的值。和unity一样偏移一个数值，防止z值接近0的时候，算出一个很大的数
        #endif

        #if !defined(PARALLAX_FUNCTION)
            #define PARALLAX_FUNCTION ParallaxOffset
        #endif
        float2 uvOffset = PARALLAX_FUNCTION(i.uv.xy, i.tangentViewDir.xy);
        i.uv.xy += uvOffset;
        i.uv.zw += uvOffset * (_DetailTex_ST.xy / _MainTex_ST.xy);                     // 细节贴图的UV也做一下偏移， 并且ST应该相对于主纹理
    #endif
}

InterpolatorsVertex MyVertexProgram(appdata v)
{
    InterpolatorsVertex o;
	UNITY_INITIALIZE_OUTPUT(Interpolators, o);										// 把结构体里的各个变量初始化为0

    UNITY_SETUP_INSTANCE_ID(v);                                                     // 用于配合GPUInstance,从而根据自身的instance id修改unity_ObjectToWorld这个矩阵的值，使得下面的UnityObjectToClipPos转换出正确的世界坐标，否则不同位置的多个对象在同一批次渲染的时候，此时他们传进来的模型空间坐标是一样的，不改变unity_ObjectToWorld矩阵的话，最后得到的世界坐标是在同一个位置（多个对象挤在同一个地方）。
    UNITY_TRANSFER_INSTANCE_ID(v, o);                                               // 把instance ID从结构体v赋值到结构体。
    o.pos = UnityObjectToClipPos(v.vertex);                                         // 裁剪坐标(名称要写死为pos，配合TRANSFER_SHADOW)

    o.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);                            // 世界坐标
    #if FOG_DEPTH 
        o.worldPos.w = o.pos.z;                                                     // 把深度存到世界坐标的第四个分量, 用另外的分量存，不直接用o.pos是因为SV_POSITION语义下，pos到了片元函数的时候已经变成屏幕坐标了（Screen Space，x ∈ [0, width]， y ∈ [0, height]）
    #endif
    o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);                                        // 偏移缩放主纹理uv
    o.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);                                      // 偏移缩放细节贴图uv
    #if defined(LIGHTMAP_ON)
        o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;           // 偏移缩放静态光照贴图uv（不用TRANSFORM_TEX是因为变量名会对不上，详情可看TRANSFORM_TEX源码）
    #endif
    
    #if defined(DYNAMICLIGHTMAP_ON)
        o.dynamicLightmapUV = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw; // 偏移缩放动态光照贴图uv（不用TRANSFORM_TEX是因为变量名会对不上，详情可看TRANSFORM_TEX源码）
    #endif

    o.normal = UnityObjectToWorldNormal(v.normal);                                  // 法线世界坐标
    
    // 判断是否在片元函数里计算副法线
    #if defined(BINORMAL_PER_FRAGMENT) 
        o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);      // 切线世界坐标
    #else
        o.tangent = UnityObjectToWorldDir(v.tangent.xyz);                           // 切线世界坐标,不用传v.tangent.w了，因为不需要在片元函数里算副法线了
        o.binormal = CreateBinormal(o.normal, o.tangent, v.tangent.w);              // 计算副法线，tangent切线的w存储的是-1或者1，用来表明正负方向的
    #endif

    // 调用unity内置宏，得到shadowCoordinates
    // 原理：裁剪坐标转换成屏幕坐标
    // 顶点的ClipPos取值范围是[-w, w], 齐次除法之后变成NDC下的坐标，范围是[-1， 1],而屏幕空间下的uv取值范围是[0, 1]
    // 由于需要转换成采样阴影贴图的uv坐标，所以要转换成取值范围是[0，w]的坐标，后面片元函数里执行齐次除法得到的屏幕空间的uv坐标，取值范围[0，1]）
    //TRANSFER_SHADOW(o);
	UNITY_TRANSFER_SHADOW(o, v.uv1);

    // 处理四个非重要光
    ComputeVertexLightColor(o);

    // 判断是否启用了视差贴图
    #if defined(_PARALLAX_MAP)
        // 判断我们是否需要支持动态合批
        #if defined(PARALLAX_SUPPORT_SCALED_DYNAMIC_BATCHING)
            // 动态合批的时候unity不会对以下两个变量进行归一化，因为视差贴图计算需要用到，所以这里手动进行归一化
            v.tangent.xyz = normalize(v.tangent.xyz);
            v.normal = normalize(v.normal);
        #endif

        // 构造一个从模型空间转换到切线空间的矩阵（切线空间基底）
        float3x3 objectToTangent = float3x3(
            v.tangent.xyz,                                          // 切线
            cross(v.normal, v.tangent.xyz) * v.tangent.w,           // 副法线  
            v.normal                                                // 法线
        );
        o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex)); // ObjSpaceViewDir会产生一个模型空间下顶点指向摄像机的向量
    #endif

    return o;
}

FragmentOutPut MyFragmentProgram(Interpolators i) 
{
    UNITY_SETUP_INSTANCE_ID(i); 
    // 判断是否启用了LOD淡入淡出
    #if defined(LOD_FADE_CROSSFADE)
        UnityApplyDitherCrossFade(i.vpos);  // 这里的i.vpos和i.pos一样都是屏幕空间坐标(x ∈ [0, width]， y ∈ [0, height]）,但i.pos做了一个0.5像素的偏移，以选中像素的中心
    #endif

    ApplyParallax(i);                       // 应用视察贴图

    float alpha = GetAlpha(i);
    // 判断是否裁剪掉
    #if defined(_RENDERING_CUTOUT)
        clip(alpha - _Cutoff);
    #endif

    InitializeFragmentNormal(i);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);                                                      // 视线方向
    float3 _SpecularTint;

    // 1 - 反射率
    float oneMinusReflectivity;         
    // 确保漫反射的材质反射率加上高光反射的反射率不超过1，并得出高光反射的反射率
    float3 albedo = DiffuseAndSpecularFromMetallic(GetAlbedo(i), GetMetallic(i), _SpecularTint, oneMinusReflectivity);      // 金属工作流
    #if defined(_RENDERING_TRANSPARENT)
        albedo *= alpha;

        // 反射的光越多，则越不透明。当没有反射率是0的时候透明度不变，当反射率是1的时候透明度也是1
        // 设反射率是r，即最终透明度a = a + (1 - a) * r = a + r - ra 而oneMinusReflectivity = 1 - r
        // 所以有1 - oneMinusReflectivity + alpha * oneMinusReflectivity = 1 - (1-r) + a * (1 - r) = a + r - ra = a + (1 - a) * r
        alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
    #endif

    float4 color = UNITY_BRDF_PBS(albedo, _SpecularTint,                        // 漫反射颜色，高光反射颜色
                            oneMinusReflectivity, GetSmoothness(i),             // 1 - 反射率，粗糙度
                            i.normal, viewDir,                                  // 世界空间下的法线和摄像机方向
                            CreateLight(i), CreateIndirectLight(i, viewDir));   // 光照数据, 间接光数据
    // 把自发光叠加上去
    color.rgb += GetEmission(i); 
    #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
        color.a = alpha;
    #endif

    FragmentOutPut output;
    // 延迟渲染
    #if defined(DEFERRED_PASS)
        // 如果用的是LDR
        #if !defined(UNITY_HDR_ON)
            // 用exp2进行对数编码，可以达到比通常情况更大的动态范围， [0, 1] ~ [1, 0.5], 猜测是为了把大于1的光照也记录下来，因为LDR范围是0~1，而HDR颜色的范围是可以超过1的
            // exp2相当于y = 2^(x), 在LDR下，unity内建的（LightPass）会用-log2（y = -log2(x)）进行解码，所以这里用exp2进行编码
            color.rgb = exp2(-color.rgb);       
        #endif

        output.gBuffer0.rgb = albedo;           // 漫反射
        output.gBuffer0.a = GetOcclusion(i);    // 自阴影
        output.gBuffer1.rgb = _SpecularTint;    // 高光颜色
        output.gBuffer1.a = GetSmoothness(i);   // 粗糙度
        output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1); // 法线世界坐标(把-1~1的取值范围转化为0~1), rgb分别用了10位，而a通道是2位，并且a通道没有使用
        output.gBuffer3 = color;

		// 判断是否启用了阴影遮罩
		// 判断平台是否支持大于4个gBuffer
		#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
			float2 shadowsMaskUV = 0;
			// 判断是否启用了光照贴图
			#if defined(LIGHTMAP_ON)
				shadowsMaskUV = i.lightmapUV;
			#endif
			output.gBuffer4 = UnityGetRawBakedOcclusions(shadowsMaskUV, i.worldPos.xyz);		// 对阴影遮罩进行采样
		#endif

    // 前向渲染
    #else
        output.color = ApplyFog(color, i);
    #endif
    return output;
}

// 没用到
float4 MyDirectionalFragmentProgram(Interpolators i) : SV_Target
{
    i.normal = normalize(i.normal);
    float3 lightDir = _WorldSpaceLightPos0.xyz;                                                         // 光照方向， 从当前片元指向光源
    float3 lightColor = _LightColor0.rgb;
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);                                  // 摄像机方向
    float3 _SpecularTint;

    // 漫反射
    float3 albedo = tex2D(_MainTex, i.uv).rgb * UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).rgb;    // 漫反射固有色
    float oneMinusReflectivity;
    // 确保漫反射的材质反射率加上高光反射的反射率不超过1，并得出高光反射的反射率
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, _SpecularTint, oneMinusReflectivity);    // 金属工作流


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
#endif