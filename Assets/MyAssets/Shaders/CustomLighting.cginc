#if !defined(CUSTOM_LIGHTING_INLCUDE)
#define CUSTOM_LIGHTING_INLCUDE

#include "CustomLightingInput.cginc"

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
void ComputeVertexLightColor(inout InterpolatorsVertex i){
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
UnityIndirect CreateIndirectLight(Interpolators i, float3 viewDir, SurfaceData surface){
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
        envData.roughness = 1 - surface.smoothness;

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
        float occlusion = surface.occlusion;
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
    // 判断是否需要切线空间
    #if REQUIRES_TANGENT_SPACE
        //float3 dpdx = ddx(i.worldPos);                                                                              // 计算自身片元与x方向上相邻的片元世界坐标的差值
        //float3 dpdy = ddy(i.worldPos);                                                                              // 计算自身片元与y方向上相邻的片元世界坐标的差值
        //i.normal = normalize(cross(dpdy, dpdx));                                                                    // 叉乘算出三角面的法线，不用原本顶点的法线了,让模型变得有棱有角
    
        // 计算切线空间下的法线（需要融合细节贴图的法线）
        float3 tangentSpaceNormal = GetTangentSpaceNormal(i);

        // 是否定义了需要在片元函数里计算副法线
        #if defined(BINORMAL_PER_FRAGMENT)
            float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);                                 // 叉乘计算副法线，切线的w存储的是-1或者1，用来表明正负方向的
        #else
            float3 binormal = i.binormal;
        #endif

        // 切线空间的法线转换到世界空间
        // i.tangent、binormal、i.normal是世界空间的向量，并且是切线空间坐标的基底
        i.normal = normalize(tangentSpaceNormal.x * i.tangent +                                                     // 切线方向偏移x
                             tangentSpaceNormal.y * binormal +                                                      // 副法线方向偏移y
                             tangentSpaceNormal.z * i.normal);                                                      // 法线方向偏移z
    #else
        i.normal = normalize(i.normal);
    #endif
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
    // 视差贴图需要用到uv，如果没有有效uv则视差贴图不生效
    #if defined(_PARALLAX_MAP) && !defined(NO_DEFAULT_UV)
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
        float2 uvOffset = PARALLAX_FUNCTION(UV_FUNCTION(i).xy, i.tangentViewDir.xy);
        UV_FUNCTION(i).xy += uvOffset;
        UV_FUNCTION(i).zw += uvOffset * (_DetailTex_ST.xy / _MainTex_ST.xy);            // 细节贴图的UV也做一下偏移， 并且ST应该相对于主纹理
    #endif
}

InterpolatorsVertex MyVertexProgram(VertexData v)
{
    InterpolatorsVertex o;
	UNITY_INITIALIZE_OUTPUT(InterpolatorsVertex, o);								// 把结构体里的各个变量初始化为0

    UNITY_SETUP_INSTANCE_ID(v);                                                     // 用于配合GPUInstance,从而根据自身的instance id修改unity_ObjectToWorld这个矩阵的值，使得下面的UnityObjectToClipPos转换出正确的世界坐标，否则不同位置的多个对象在同一批次渲染的时候，此时他们传进来的模型空间坐标是一样的，不改变unity_ObjectToWorld矩阵的话，最后得到的世界坐标是在同一个位置（多个对象挤在同一个地方）。
    UNITY_TRANSFER_INSTANCE_ID(v, o);                                               // 把instance ID从结构体v赋值到结构体o。
    
    // 检查是否有有效的uv
    #if !defined(NO_DEFAULT_UV)
        o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);                                        // 偏移缩放主纹理uv
        o.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);                                      // 偏移缩放细节贴图uv

        // 检查是否启用了顶点偏移
        #if VERTEX_DISPLACEMENT
            float displacement = tex2Dlod(_DisplacementMap, float4(o.uv.xy, 0, 0)).g;   // 对视差贴图进行采样，不使用mipmap
            displacement = (displacement - 0.5) * _DisplacementStrength;                // 0~1转换为-0.5~0.5后再乘以强度
            v.normal = normalize(v.normal);
            v.vertex.xyz += v.normal * displacement;
        #endif
    #endif

    o.pos = UnityObjectToClipPos(v.vertex);                                         // 裁剪坐标(名称要写死为pos，配合TRANSFER_SHADOW)

    o.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);                            // 世界坐标
    #if FOG_DEPTH 
        o.worldPos.w = o.pos.z;                                                     // 把深度存到世界坐标的第四个分量, 用另外的分量存，不直接用o.pos是因为SV_POSITION语义下，pos到了片元函数的时候已经变成屏幕坐标了（Screen Space，x ∈ [0, width]， y ∈ [0, height]）
    #endif
    #if defined(LIGHTMAP_ON)
        o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;           // 偏移缩放静态光照贴图uv（不用TRANSFORM_TEX是因为变量名会对不上，详情可看TRANSFORM_TEX源码）
    #endif
    
    #if defined(DYNAMICLIGHTMAP_ON)
        o.dynamicLightmapUV = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw; // 偏移缩放动态光照贴图uv（不用TRANSFORM_TEX是因为变量名会对不上，详情可看TRANSFORM_TEX源码）
    #endif

    o.normal = UnityObjectToWorldNormal(v.normal);                                  // 法线世界坐标
    
    // 判断是否需要切线空间
    #if REQUIRES_TANGENT_SPACE
        // 判断是否在片元函数里计算副法线
        #if defined(BINORMAL_PER_FRAGMENT) 
            o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);      // 切线世界坐标
        #else
            o.tangent = UnityObjectToWorldDir(v.tangent.xyz);                           // 切线世界坐标,不用传v.tangent.w了，因为不需要在片元函数里算副法线了
            o.binormal = CreateBinormal(o.normal, o.tangent, v.tangent.w);              // 计算副法线，tangent切线的w存储的是-1或者1，用来表明正负方向的
        #endif
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
    
    InitializeFragmentNormal(i);            // 初始化法线

    SurfaceData surface;
    // 判断是否有重写的获取表面属性的方法
    #if defined(SURFACE_FUNCTION)
        // 先给个默认值
        surface.normal = i.normal;
        surface.albedo = 1;
        surface.alpha = 1;
        surface.emission = 0;
        surface.metallic = 0;
        surface.occlusion = 1;
        surface.smoothness = 0.5;

        SurfaceParameters sp;
        sp.normal = i.normal;
        sp.position = i.worldPos.xyz;
        sp.uv = UV_FUNCTION(i);

        // 对surface进行赋值
        SURFACE_FUNCTION(surface, sp);
    #else
        surface.normal = i.normal;
        surface.albedo = ALBEDO_FUNCTION(i);
        surface.alpha = GetAlpha(i);
        surface.emission = GetEmission(i);
        surface.metallic = GetMetallic(i);
        surface.occlusion = GetOcclusion(i);
        surface.smoothness = GetSmoothness(i);
    #endif

    i.normal = surface.normal; // 因为上面的SURFACE_FUNCTION可能会改变法线，这里把改变后的法线赋回给i.normal, 下面的代码可以继续用i.normal

    float alpha = surface.alpha;
    // 判断是否裁剪掉
    #if defined(_RENDERING_CUTOUT)
        clip(alpha - _Cutoff);
    #endif

    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);                                                      // 视线方向
    float3 _SpecularTint;

    // 1 - 反射率
    float oneMinusReflectivity;         
    // 确保漫反射的材质反射率加上高光反射的反射率不超过1，并得出高光反射的反射率
    float3 albedo = DiffuseAndSpecularFromMetallic(surface.albedo, surface.metallic, _SpecularTint, oneMinusReflectivity);      // 金属工作流
    #if defined(_RENDERING_TRANSPARENT)
        albedo *= alpha;

        // 反射的光越多，则越不透明。当没有反射率是0的时候透明度不变，当反射率是1的时候透明度也是1
        // 设反射率是r，即最终透明度a = a + (1 - a) * r = a + r - ra 而oneMinusReflectivity = 1 - r
        // 所以有1 - oneMinusReflectivity + alpha * oneMinusReflectivity = 1 - (1-r) + a * (1 - r) = a + r - ra = a + (1 - a) * r
        alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
    #endif

    float4 color = UNITY_BRDF_PBS(albedo, _SpecularTint,                                    // 漫反射颜色，高光反射颜色
                            oneMinusReflectivity, surface.smoothness,                       // 1 - 反射率，平滑度
                            i.normal, viewDir,                                              // 世界空间下的法线和摄像机方向
                            CreateLight(i), CreateIndirectLight(i, viewDir, surface));      // 光照数据, 间接光数据, 表面数据
    // 把自发光叠加上去
    color.rgb += surface.emission; 
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

        output.gBuffer0.rgb = albedo;                       // 漫反射
        output.gBuffer0.a = surface.occlusion;              // 自阴影
        output.gBuffer1.rgb = _SpecularTint;                // 高光颜色
        output.gBuffer1.a = surface.smoothness;             // 粗糙度
        output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);  // 法线世界坐标(把-1~1的取值范围转化为0~1), rgb分别用了10位，而a通道是2位，并且a通道没有使用
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

#endif