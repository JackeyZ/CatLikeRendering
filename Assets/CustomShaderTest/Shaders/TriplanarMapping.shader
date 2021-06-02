// 三向贴图，适合代码生成的各种地形、洞穴mesh
Shader "Custom/TriplanarMapping"
{
    Properties
    {
        [NoScaleOffset] _MainTex("Albedo", 2D) = "white" {}                     // 反射率贴图
        [NoScaleOffset] _MOHSMap("MOHS", 2D) = "white" {}                       // 金属(R)、自阴影(G)、高度(B)、平滑度(A)贴图
        [NoScaleOffset] _NormalMap("Normals", 2D) = "white" {}                  // 法线贴图
        
        [NoScaleOffset] _TopMainTex("Top Albedo", 2D) = "white" {}              // 上表面用的反射率贴图
        [NoScaleOffset] _TopMOHSMap("Top MOHS", 2D) = "white" {}                // 上表面用的金属(R)、自阴影(G)、高度(B)、平滑度(A)贴图
        [NoScaleOffset] _TopNormalMap("Top Normals", 2D) = "white" {}           // 上表面用的法线贴图

		_MapScale("Map Scale", Float) = 1                                       // 上面三个贴图的统一的缩放参数
        _BlendOffset("Blend Offset", Range(0, 0.5)) = 0.25                      // 三向权重混合偏移,表示三个方向贴图的融合程度，越大，重叠的部分越多
        _BlendExponent("Blend Exponent", Range(1, 8)) = 2                       // 混合指数，表示三个方向贴图的融合程度，越大，重叠的部分越少
        _BlendHeightStrength("Blend Height Strength", Range(0, 0.99)) = 0.5     // 高度图(_MOHSMap里的h)混合强度
    }

    CustomEditor "TriplanarShaderGUI"

    // 定义宏，应用到所有的pass
    CGINCLUDE
    ENDCG

    SubShader
    {
        Pass
        {
            Tags {
                "LightMode" = "ForwardBase"
            }

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
            // 是否启用GPU实例化（但是并不支持ForwardAdd的Pass，所以前向渲染的时候点光源并不能用GPUInstance合批）
            #pragma multi_compile_instancing
            // 是否启用顶部贴图
            #pragma shader_feature _SEPARATE_TOP_MAPS

            // 表示是基础pass
            #define FORWARD_BASE_PASS      

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram
            
            #include "CustomTriplanarMapping.cginc"
            #include "CustomLighting.cginc"

            ENDCG
        }

        Pass
        {
            Tags {
                "LightMode" = "ForwardAdd"
            }
			Blend One One
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
            // 是否启用顶部贴图
            #pragma shader_feature _SEPARATE_TOP_MAPS

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram
            
            #include "CustomTriplanarMapping.cginc"
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
            // 是否启用顶部贴图
            #pragma shader_feature _SEPARATE_TOP_MAPS
            
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram 

            // 表示是延迟渲染的pass
            #define DEFERRED_PASS    
            
            #include "CustomTriplanarMapping.cginc"
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
            
			#pragma vertex MyShadowVertexProgram
			#pragma fragment MyShadowFragmentProgram
            
            #include "CustomShadows.cginc"
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
            // 是否启用顶部贴图
            #pragma shader_feature _SEPARATE_TOP_MAPS

            #pragma vertex MyLightmappingVertexProgram 
            #pragma fragment MyLightmappingFragmentProgram 
            
            // 表示需要用到世界空间的法线
            #define META_PASS_NEEDS_NORMALS
            // 表示需要用到世界坐标
            #define META_PASS_NEEDS_POSITION

            #include "CustomTriplanarMapping.cginc"
            #include "CustomLightmapping.cginc"

            ENDCG
        }
    }
}
