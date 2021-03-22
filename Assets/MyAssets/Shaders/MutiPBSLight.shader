Shader "Custom/MutiPBSLight"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)                                  // 漫反射反射颜色 (这里命名一定要用_Color,因为生成静态光照贴图的时候unity会从游戏对象的材质球上的_Color属性中的a通道取透明度)
        _MainTex ("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5                              // 透明度裁剪阈值 (这里命名一定要用_Cutoff,因为生成静态光照贴图的时候unity会从游戏对象的材质球上的_Cutoff属性取阈值)

        [NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}                  // 法线贴图
        _BumpScale("BumpScale", Range(0, 1)) = 0.5

        [NoScaleOffset] _MetallicMap("Metallic", 2D) = "white" {}               // 金属度贴图
        [Gamma]_Metallic("Metallic", Range(0, 1)) = 0                           // 金属度
        
        _Smoothness("Smoothness", Range(0, 1)) = 0.5                            // 粗糙度

        _DetailTex("Detail Albedo", 2D) = "gray" {}                             // 细节贴图 
        [NoScaleOffset] _DetailNormalMap("Detail Normals", 2D) = "bump" {}      // 细节贴图的法线贴图 
        _DetailBumpScale("Detail Bump Scale", Range(0, 1)) = 0.5                // 凹凸缩放
        [NoScaleOffset] _DetailMask("Detail Mask", 2D) = "white" {}             // 细节遮罩

        [NoScaleOffset] _EmissionMap("Emission", 2D) = "black" {}               // 自发光贴图
        _Emission("Emission", Color) = (0, 0, 0)                                // 自发光颜色

        [NoScaleOffset] _ParallaxMap("Parallax", 2D) = "black" {}               // 视差贴图（本质是一个高度图）
        _ParallaxStrength("Parallax Strength", Range(0, 0.1)) = 0               // 视差强度

        [NoScaleOffset] _OcclusionMap("Occlusion", 2D) = "white" {}             // 自阴影
        _OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1               // 自阴影强度

        [HideInInspector] _SrcBlend("_SrcBlend", Float) = 1                     // 新渲染片元颜色权重
        [HideInInspector] _DstBlend("_DstBlend", Float) = 0                     // color buffer里面的颜色权重
        [HideInInspector] _ZWrite("_ZWrite", Float) = 1                         // 是否进行深度写入
    }
    
    CustomEditor "MutiPBSShaderGUI"

    // 定义宏，应用到所有的pass
    CGINCLUDE
        // 表明用片元函数计算副法线
        #define BINORMAL_PER_FRAGMENT       
        // 表明基于距离来计算雾浓度,如果不定义则基于深度
        //#define FOG_DISTANCE
        // 是否对视差偏移进行限制
        //#define PARALLAX_OFFSET_LIMITING 
        // 视差归一的时候用的偏移值
        //#define PARALLAX_BIAS 0
        // 定义视差贴图里光追的步长
        //#define PARALLAX_RAYMARCHING_STEPS 10
        // 定义视差贴图里光追步长之间二分查找交点的次数
        #define PARALLAX_RAYMARCHING_SEARCH_STEPS 5
        // 定义视差贴图是否运用遮挡过渡计算
        #define PARALLAX_RAYMARCHING_INTERPOLATE
        // 定义计算视差偏移的方法
        #define PARALLAX_FUNCTION ParallaxRaymarching
        // 定义视差贴图支持动态合批
        #define PARALLAX_SUPPORT_SCALED_DYNAMIC_BATCHING
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags {
                "LightMode" = "ForwardBase"
            }

            // 两个参数分别是：新渲染的片元颜色混合时的权重、 color buffer的颜色混合时的权重
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            // 用3.0，确保PBS达到最好的效果
            #pragma target 3.0             

            // 包含SHADOWS_SCREEN、LIGHTMAP_ON、VERTEXLIGHT_ON、DIRLIGHTMAP_ON等关键字
            // SHADOWS_SCREEN：接受阴影关键字，Unity将查找启用了SHADOWS_SCREEN关键字的着色器变体
            // LIGHTMAP_ON：是否使用静态光照贴图（unity会自动检索有LIGHTMAP_ON关键字的pass，传入静态光照贴图）
            // DIRLIGHTMAP_ON：定义光照方向贴图的关键字
            // VERTEXLIGHT_ON：定义顶点光源的关键字，unity只有点光源支持顶点光源
            // DYNAMICLIGHTMAP_ON: 是否使用了动态间接光照贴图(对应设置Lighting -> Realtime Lighting -> Realtime Global Illumination)，用于在启用动态光的时候，间接光贴图能够根据动态光实时的位置和方向进行动态渲染。环境光也会渲染进贴图
            #pragma multi_compile_fwdbase
            // 雾效(三关键字FOG_LINEAR,FOG_EXP,FOG_EXP2)对应Lighting window - Other Setting - Fog - Mode
            #pragma multi_compile_fog
            // LOD淡入淡出关键字（LOD Group组件里设置）
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            // 是否启用GPU实例化（但是并不支持ForwardAdd的Pass，所以前向渲染的时候点光源并不能用GPUInstance合批）
            #pragma multi_compile_instancing
            // 支持lod fade 的GPU实例化(新版本不用了，默认开启)
            //#pragma instancing_options lodfade

            // 不透明渲染、全透明度裁剪、淡入半透明度渲染、 半透明渲染
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
            // 是否使用金属度贴图
            #pragma shader_feature _METALLIC_MAP
            // 粗糙度是否来源于变量 或 主纹理的alpha通道 或 金属贴图的alpha通道
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            // 是否使用法线贴图
            #pragma shader_feature _NORMAL_MAP
            // 是否使用视差贴图
            #pragma shader_feature _PARALLAX_MAP
            // 是否使用自阴影贴图
            #pragma shader_feature _OCCLUSION_MAP
            // 是否使用自发光贴图
            #pragma shader_feature _EMISSION_MAP
            // 是否使用细节贴图
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            // 是否使用细节法线贴图
            #pragma shader_feature _DETAIL_NORMAL_MAP
            // 是否使用细节遮罩贴图
            #pragma shader_feature _DETAIL_MASK

            // 表示是基础pass
            #define FORWARD_BASE_PASS       

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram
            
            #include "CustomLighting.cginc"

            ENDCG
        }

        Pass
        {
            Tags {
                "LightMode" = "ForwardAdd"
            }
            Blend [_SrcBlend] One
            ZWrite Off      // ForwardBase路径里已经写入了，这里没必要再写入

            CGPROGRAM
            // 用3.0，确保PBS达到最好的效果
            #pragma target 3.0             

            // 定义多个变体，unity会根据光源类型enable不同的关键字
            // multi_compile_fwdadd相当于 #pragma multi_compile DIRECTIONAL DIRECTIONAL_COOKIE POINT POINT_COOKIE SPOT
            // multi_compile_fwdadd_fullshadows相当于 #pragma multi_compile DIRECTIONAL DIRECTIONAL_COOKIE POINT POINT_COOKIE SPOT SHADOWS_CUBE SHADOWS_DEPTH SHADOWS_SCREEN SHADOWS_SOFT
            #pragma multi_compile_fwdadd_fullshadows
            // 雾效
            #pragma multi_compile_fog
            // LOD淡入淡出关键字（LOD Group组件里设置）
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            
            // 不透明渲染、全透明度裁剪、淡入半透明度渲染、 半透明渲染
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
            // 是否使用金属度贴图
            #pragma shader_feature _METALLIC_MAP
            // 粗糙度是否来源于变量 或 主纹理的alpha通道 或 金属贴图的alpha通道
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            // 是否使用法线贴图
            #pragma shader_feature _NORMAL_MAP
            // 是否使用细节遮罩贴图
            #pragma shader_feature _DETAIL_MASK
            // 是否使用细节贴图
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            // 是否使用细节法线贴图
            #pragma shader_feature _DETAIL_NORMAL_MAP

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "CustomLighting.cginc"

            ENDCG
        }

        // 延迟渲染pass
        pass
        {
            Tags
            {
                "LightMode" = "Deferred"
            }
            CGPROGRAM

            #pragma target 3.0
            // 不支持写入多个渲染目标的平台不编译该pass，nomrt即no multiple render targets
            #pragma exclude_renderers nomrt 
            
            // 是否启用GPU实例化
            #pragma multi_compile_instancing

            // 包含UNITY_HDR_ON、LIGHTMAP_ON等关键字
            // UNITY_HDR_ON：是否是HDR渲染（高动态光照渲染）， 对应ProjectSetting - Graphics - Tier Settings - Use HDR
            // LIGHTMAP_ON：是否使用光照贴图
            #pragma multi_compile_prepassfinal
            // LOD淡入淡出关键字（LOD Group组件里设置）
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            
            // 是否全透明度裁剪
            #pragma shader_feature _ _RENDERING_CUTOUT
            // 是否使用金属度贴图
            #pragma shader_feature _METALLIC_MAP
            // 粗糙度是否来源于变量 或 主纹理的alpha通道 或 金属贴图的alpha通道
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            // 是否使用法线贴图
            #pragma shader_feature _NORMAL_MAP
            // 是否使用自阴影贴图
            #pragma shader_feature _OCCLUSION_MAP
            // 是否使用自发光贴图
            #pragma shader_feature _EMISSION_MAP 
            // 是否使用细节贴图
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            // 是否使用细节法线贴图
            #pragma shader_feature _DETAIL_NORMAL_MAP
            // 是否使用细节遮罩贴图
            #pragma shader_feature _DETAIL_MASK   

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram 

            // 表示是延迟渲染的pass
            #define DEFERRED_PASS    
            
            #include "CustomLighting.cginc"

			ENDCG

        }

        Pass 
        {
            Tags 
            {
                "LightMode" = "ShadowCaster" // 渲染阴影贴图的pass(投射阴影)
            }

            CGPROGRAM
            #pragma target 3.0
            
            #pragma multi_compile_shadowcaster
            // 阴影支持GPUInstance
            #pragma multi_compile_instancing
            // LOD淡入淡出关键字（LOD Group组件里设置）
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // 渲染模式：不透明渲染、全透明度裁剪、淡入半透明度渲染、 半透明渲染
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
            // 是否使用半透明阴影
            #pragma shader_feature _SEMITRANSPARENT_SHADOWS
            // 粗糙度来源是否是主纹理的a通道
            #pragma shader_feature _SMOOTHNESS_ALBEDO

            #include "CustomShadows.cginc"
            #pragma vertex MyShadowVertexProgram
            #pragma fragment MyShadowFragmentProgram
            ENDCG
        }

        Pass
        {
            Tags
            {
                "LightMode" = "Meta"       // 烘焙静态光照贴图或实时光照贴图的时候unity会在需要间接光数据的时候访问这个pass，从而得到Albedo和emissive提供给Enlighten系统
                                           // 实时光照贴图是为了让静态物体的间接光能动态生成, 否则光源位置改变的时候静态物体的间接光会错误
            }
            Cull Off
            CGPROGRAM
            #pragma vertex MyLightmappingVertexProgram 
            #pragma fragment MyLightmappingFragmentProgram 
            
            // 是否使用金属度贴图
            #pragma shader_feature _METALLIC_MAP    
            // 粗糙度是否来源于变量 或 主纹理的alpha通道 或 金属贴图的alpha通道
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC    
            // 是否使用自发光贴图
            #pragma shader_feature _EMISSION_MAP   
            // 是否使用细节贴图
            #pragma shader_feature _DETAIL_ALBEDO_MAP   
            // 是否使用细节遮罩贴图
            #pragma shader_feature _DETAIL_MASK   

            #include "CustomLightmapping.cginc"

            ENDCG
        }
    }
}
