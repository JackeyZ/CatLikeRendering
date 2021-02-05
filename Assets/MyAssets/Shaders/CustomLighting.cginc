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

// 顶点函数输入
struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;                             // 光照贴图uv（LIGHTMAP_ON关键字启用的时候有效）
};

// 片元函数输入
struct Interpolators
{
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
    SHADOW_COORDS(5)

    // 判断是否开启了顶点光源
    #if defined(VERTEXLIGHT_ON) 
        float3 vertexLightColor : TEXCOORD6;
    #endif

    // 判断是否使用光照贴图
    #if defined(LIGHTMAP_ON) 
        float2 lightmapUV : TEXCOORD6;                 // 光照贴图uv，与顶点光照互斥，所以这里也使用TEXCOORD6
    #endif
};

// 片元函数返回结构体
struct FragmentOutPut{
    #if defined(DEFERRED_PASS)
        float4 gBuffer0 : SV_TARGET0;
        float4 gBuffer1 : SV_TARGET1;
        float4 gBuffer2 : SV_TARGET2;
        float4 gBuffer3 : SV_TARGET3;
    #else
        float4 color : SV_Target;
    #endif
};

float4 _Color;
sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;
float _Cutoff;                                  // 透明度裁剪阈值

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;             // 法线凹凸感缩放

sampler2D _MetallicMap;                         // 金属度贴图
float _Metallic;                                // 金属度
float _Smoothness;                              // 粗糙度

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
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
    #if defined(_DETAIL_ALBEDO_MAP)
        float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * details, GetDetailMask(i));
    #endif
    return albedo;
}

// 获得透明度
float GetAlpha(Interpolators i){
    float alpha = _Color.a;
    // 如果粗糙度来源不是主纹理的a通道
    #if !defined(_SMOOTHNESS_ALBEDO)
        alpha = _Color.a * tex2D(_MainTex, i.uv.xy).a;
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

UnityLight CreateLight(Interpolators i){
    // 光照数据结构体
    UnityLight light;
    #if defined(DEFERRED_PASS)
        light.dir = float3(0, 1, 0);
        light.color = 0;
    #else
        float3 lightDir = _WorldSpaceLightPos0.xyz;
        #if defined (POINT) || defined(SPOT) || defined(POINT_COOKIE)
        lightDir = _WorldSpaceLightPos0.xyz - i.worldPos.xyz;           // _WorldSpaceLightPos0：定向光表示光照方向， 点光源则表示光源位置 
        #endif
        light.dir = normalize(lightDir); 

        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);            // 调用unity内置的衰减方法，阴影的采样也在这里面，第二个参数就是用来算阴影的
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
        #else
            // 球谐光照
            indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
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

Interpolators MyVertexProgram(appdata v)
{
    Interpolators o;
    o.pos = UnityObjectToClipPos(v.vertex);                                         // 裁剪坐标(名称要写死为pos，配合TRANSFER_SHADOW)
    o.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);                            // 世界坐标
    #if FOG_DEPTH 
        o.worldPos.w = o.pos.z;                                                     // 把深度存到世界坐标的第四个分量, 用另外的分量存，不直接用o.pos是因为SV_POSITION语义下，pos到了片元函数的时候已经变成屏幕坐标了
    #endif
    o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);                                        // 偏移缩放主纹理uv
    o.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);                                      // 偏移缩放细节贴图uv
    #if defined(LIGHTMAP_ON)
        o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;           // 偏移缩放光照贴图uv
    #endif

    o.normal = UnityObjectToWorldNormal(v.normal);                                  // 法线世界坐标
    
    // 判断是否在片元函数里计算副法线
    #if defined(BINORMAL_PER_FRAGMENT) 
        o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);      // 切线世界坐标
    #else
        o.tangent = UnityObjectToWorldDir(v.tangent.xyz);                           // 切线世界坐标,不用传v.tangent.w了，因为不需要在片元函数里算副法线了
        o.binormal = CreateBinormal(o.normal, o.tangent, v.tangent.w);              // 计算副法线
    #endif

    // 调用unity内置宏，得到shadowCoordinates
    // 原理：裁剪坐标转换成屏幕坐标
    // 顶点的ClipPos取值范围是[-w, w], 齐次除法之后变成NDC下的坐标，范围是[-1， 1],而屏幕空间下的uv取值范围是[0, 1]
    // 由于需要转换成采样阴影贴图的uv坐标，所以要转换成取值范围是[0，w]的坐标，后面片元函数里执行齐次除法得到的屏幕空间的uv坐标，取值范围[0，1]）
    TRANSFER_SHADOW(o);

    // 处理四个非重要光
    ComputeVertexLightColor(o);
    return o;
}

FragmentOutPut MyFragmentProgram(Interpolators i)
{
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
    float3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;                                              // 漫反射固有色
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