using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

/// <summary>
/// 光滑度来自哪里
/// </summary>
enum SmoothnessSource
{
    /// <summary>
    /// 与_Smoothness变量一致
    /// </summary>
    Uniform,

    /// <summary>
    /// 主纹理的alpha通道
    /// </summary>
    Albedo,

    /// <summary>
    ///  金属贴图的alpha通道
    /// </summary>
    Metallic,
}

/// <summary>
/// 渲染模式
/// </summary>
enum RenderingMode
{
    /// <summary>
    /// 不透明
    /// </summary>
    Opaque,

    /// <summary>
    /// 透明裁剪
    /// </summary>
    Cutout,

    /// <summary>
    /// 淡入半透明, 无论漫反射还是高光都进行半透明处理
    /// </summary>
    Fade,

    /// <summary>
    /// 半透明，只对漫反射进行半透明处理。 如玻璃，则不需要对高光进行半透明处理
    /// </summary>
    Transparent
}

/// <summary>
/// 渲染模式设置
/// </summary>
struct RenderingSettings {
    public RenderQueue queue;               // 渲染队列
    public string renderType;               // 渲染类型字符串
    public BlendMode srcBlend, dstBlend;    // 混合权重
    public bool zWrite;

    // 各个渲染模式的设置，和枚举RenderingMode对应
    public static RenderingSettings[] modes =
    {
        new RenderingSettings(){
            queue = RenderQueue.Geometry,       // 不透明
            renderType = "",
            srcBlend = BlendMode.One,
            dstBlend = BlendMode.Zero,
            zWrite = true,
        },
        new RenderingSettings(){
            queue = RenderQueue.AlphaTest,      // 全透明cutout,会直接裁剪掉透明度未达到阈值的片元
            renderType = "TransparentCutout",
            srcBlend = BlendMode.One,
            dstBlend = BlendMode.Zero,
            zWrite = true,
        },
        new RenderingSettings(){
            queue = RenderQueue.Transparent,    // 淡入半透明, 无论漫反射还是高光都进行半透明处理
            renderType = "Transparent",
            srcBlend = BlendMode.SrcAlpha,
            dstBlend = BlendMode.OneMinusSrcAlpha,
            zWrite = false,
        },
        new RenderingSettings(){
            queue = RenderQueue.Transparent,    // 半透明，只对漫反射进行半透明处理。如玻璃，则不需要对高光进行半透明处理
            renderType = "Transparent",
            srcBlend = BlendMode.One,           // 已在片元着色器提前用透明度对漫反射进行处理，这里用One，来避免对高光进行透明度处理
            dstBlend = BlendMode.OneMinusSrcAlpha,
            zWrite = false,
        },
    };
}

public class MutiPBSShaderGUI : BaseShaderGUi
{
    protected bool shouldShowAlphaCutoff;

    protected override void ThisOnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        DoRenderingMode();
        DoCullMode();
        DoMain();
        DoSecondary();
        DoAdvanced();
    }

    protected void DoMain()
    {
        if (shouldShowAlphaCutoff)
        {
            DoAlphaCutoff();
        }

        GUILayout.Label("Main Maps", EditorStyles.boldLabel);

        MaterialProperty mainTex = FindProperty("_MainTex");  
        editor.TexturePropertySingleLine(MakeLabel(mainTex, "Albedo(RGB)"), mainTex, FindProperty("_Color"));

        DoMetallic();

        DoSmoothness();

        DoNormals();

        DoParallax();

        DoOcclusion();

        DoEmission();

        editor.TextureScaleOffsetProperty(mainTex);
    }

    protected void DoRenderingMode()
    {
        RenderingMode mode = RenderingMode.Opaque;
        shouldShowAlphaCutoff = false;
        if (IsKeywordEnabled("_RENDERING_CUTOUT"))
        {
            mode = RenderingMode.Cutout;
            shouldShowAlphaCutoff = true;
        }
        else if (IsKeywordEnabled("_RENDERING_FADE"))
        {
            mode = RenderingMode.Fade;
        }
        else if (IsKeywordEnabled("_RENDERING_TRANSPARENT"))
        {
            mode = RenderingMode.Transparent;
        }

        EditorGUI.BeginChangeCheck();
        mode = (RenderingMode)EditorGUILayout.EnumPopup(MakeLabel("Rendering Mode"), mode);
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Rendering Mode");                                                     // 记录操作，支持回退
            // 设置keyword
            SetKeyword("_RENDERING_CUTOUT", mode == RenderingMode.Cutout);
            SetKeyword("_RENDERING_FADE", mode == RenderingMode.Fade);
            SetKeyword("_RENDERING_TRANSPARENT", mode == RenderingMode.Transparent);

            // 更新渲染队列和类型
            RenderingSettings settings = RenderingSettings.modes[(int)mode];
            foreach (Material m in editor.targets)
            {
                m.renderQueue = (int)settings.queue;
                m.SetOverrideTag("RenderType", settings.renderType);                             // 用于支持“替换着色器”
                m.SetInt("_SrcBlend", (int)settings.srcBlend);
                m.SetInt("_DstBlend", (int)settings.dstBlend);
                m.SetInt("_ZWrite", settings.zWrite ? 1 : 0);
            }
        }
        // 如果是半透明渲染模式
        if(mode == RenderingMode.Fade || mode == RenderingMode.Transparent)
        {
            // 显示是否使用半透明投影的开关
            DoSemitransparentShadows();
        }

        GUILayout.Label("RenderQueue: " + target.renderQueue);
    }

    void DoSemitransparentShadows()
    {
        EditorGUI.BeginChangeCheck();
        bool smitransparentShadows = EditorGUILayout.Toggle(MakeLabel("Semitransp.Shadows", "半透明阴影"), IsKeywordEnabled("_SEMITRANSPARENT_SHADOWS"));
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_SEMITRANSPARENT_SHADOWS", smitransparentShadows);
        }
        // 如果不使用半透明，则使用全透明阴影裁剪
        if (!smitransparentShadows)
        {
            shouldShowAlphaCutoff = true;
        }
    }

    // 剔除模式的下拉框
    void DoCullMode() {
        CullMode cull_mode = (CullMode)(int)target.GetFloat("_Cull");
        EditorGUI.BeginChangeCheck();
        cull_mode = (CullMode)EditorGUILayout.EnumPopup(MakeLabel("Cull Mode"), cull_mode);
        if (EditorGUI.EndChangeCheck())
        {
            this.target.SetInt("_Cull", (int)cull_mode);
        }
    }

    void DoAlphaCutoff()
    {
        MaterialProperty slider = FindProperty("_Cutoff");
        editor.ShaderProperty(slider, MakeLabel(slider, "透明度裁剪阈值"));
    }

    void DoMetallic()
    {
        MaterialProperty map = FindProperty("_MetallicMap");
        Texture tex = map.textureValue;
        EditorGUI.BeginChangeCheck();                                                                                       // 开始检查更变
        editor.TexturePropertySingleLine(MakeLabel(map, "Metallic(R)"), map, FindProperty("_Metallic"));
        if (EditorGUI.EndChangeCheck() && tex != map.textureValue)                                                                                     // 结束检查更变，并返回是否有变化
        {
            SetKeyword("_METALLIC_MAP", map.textureValue);
        }
    }

    void DoSmoothness()
    {
        SmoothnessSource source = SmoothnessSource.Uniform;
        if (this.IsKeywordEnabled("_SMOOTHNESS_ALBEDO"))
        {
            source = SmoothnessSource.Albedo;
        }
        else if (this.IsKeywordEnabled("_SMOOTHNESS_METALLIC")) 
        {
            source = SmoothnessSource.Metallic;
        }

        // 粗糙度滑块
        EditorGUI.indentLevel += 2;                                                 // 缩进
        MaterialProperty slider = FindProperty("_Smoothness");
        editor.ShaderProperty(slider, MakeLabel(slider));
        EditorGUI.indentLevel += 1;

        // 粗糙度来源
        EditorGUI.BeginChangeCheck();
        source = (SmoothnessSource)EditorGUILayout.EnumPopup(MakeLabel("Source", "粗糙度来源"), source);
        if (EditorGUI.EndChangeCheck())
        {
            this.RecordAction("Smoothness Source");
            SetKeyword("_SMOOTHNESS_ALBEDO", source == SmoothnessSource.Albedo);
            SetKeyword("_SMOOTHNESS_METALLIC", source == SmoothnessSource.Metallic);
        }

        EditorGUI.indentLevel -= 3;
    }

    void DoNormals()
    {
        MaterialProperty map = FindProperty("_NormalMap");
        Texture tex = map.textureValue;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map), map, map.textureValue ? FindProperty("_BumpScale") : null);
        if (EditorGUI.EndChangeCheck() && tex != map.textureValue)// 判断tex != map.textureValue是为了防止多个材质球同时修改的时候，滑动_BumpScale导致错误激活keyword的问题
        {
            SetKeyword("_NORMAL_MAP", map.textureValue);
        }
    }

    void DoEmission()
    {
        MaterialProperty map = FindProperty("_EmissionMap");
        Texture tex = map.textureValue;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertyWithHDRColor(MakeLabel(map, "Emission(RGB)"), map, FindProperty("_Emission"), false);
        editor.LightmapEmissionProperty(2);         // 烘焙的toggle选项（选择是将静态物体的自发光烘焙到实时间接光光照贴图，还是静态光照贴图，还是不烘焙）
        if (EditorGUI.EndChangeCheck())
        {
            if(tex != map.textureValue)
            {
                SetKeyword("_EMISSION_MAP", map.textureValue);
                if (map.textureValue)
                {
                    target.SetColor("_Emission", new Color(1, 1, 1));
                }
            }

            // 遍历所有选中的材质球
            foreach (Material m in editor.targets)
            {
                // 当创建一个新的材质球的时候，unity会把EmissiveIsBlack赋值给globalIlluminationFlags,表示跳过自发光
                // （EmissiveIsBlack是当自发光颜色是黑色的时候，用于跳过自发光渲染的，由于这个标志仅在编辑器下设置，所以如果后面用代码动态修改颜色，则会出错。）
                // 这里用的LightmapEmissionProperty是没有EmissiveIsBlack标志的，所以这里禁止设置EmissiveIsBlack标志
                m.globalIlluminationFlags &= ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
            }
        }
    }

    /// <summary>
    /// 视差贴图
    /// </summary>
    void DoParallax()
    {
        MaterialProperty map = FindProperty("_ParallaxMap");
        Texture tex = map.textureValue;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map, "Parallax(G)"), map, map.textureValue ? FindProperty("_ParallaxStrength") : null);
        if(EditorGUI.EndChangeCheck() && tex != map.textureValue)
        {
            SetKeyword("_PARALLAX_MAP", map.textureValue);
        }
    }

    void DoOcclusion()
    {
        MaterialProperty map = FindProperty("_OcclusionMap");
        Texture tex = map.textureValue;
        EditorGUI.BeginChangeCheck();                                                                                       // 开始检查更变
        editor.TexturePropertySingleLine(MakeLabel(map, "Occlusion(R)"), map, map.textureValue ? FindProperty("_OcclusionStrength") : null);
        if (EditorGUI.EndChangeCheck() && tex != map.textureValue)                                                                                     // 结束检查更变，并返回是否有变化
        {
            SetKeyword("_OCCLUSION_MAP", map.textureValue);
        }
    }

    protected void DoSecondary()
    {
        GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);

        MaterialProperty detailTex = FindProperty("_DetailTex");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(detailTex, "Albedo(RGB) multiplied by 2"), detailTex);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_DETAIL_ALBEDO_MAP", detailTex.textureValue);
        }
        DoSecondaryNormals();
        DoDetailMask();
        editor.TextureScaleOffsetProperty(detailTex);
    }

    void DoSecondaryNormals()
    {
        MaterialProperty map = FindProperty("_DetailNormalMap");
        Texture tex = map.textureValue;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map), map, map.textureValue ? FindProperty("_DetailBumpScale") : null);
        if (EditorGUI.EndChangeCheck() && tex != map.textureValue)
        {
            SetKeyword("_DETAIL_NORMAL_MAP", map.textureValue);
        }
    }

    void DoDetailMask()
    {
        MaterialProperty map = FindProperty("_DetailMask");
        EditorGUI.BeginChangeCheck();                                                                                       // 开始检查更变
        editor.TexturePropertySingleLine(MakeLabel(map, "_DetailMask(A)"), map);
        if (EditorGUI.EndChangeCheck())                                                                                     // 结束检查更变，并返回是否有变化
        {
            SetKeyword("_DETAIL_MASK", map.textureValue);
        }
    }

    protected void DoAdvanced()
    {
        GUILayout.Label("Advanced Options", EditorStyles.boldLabel);
        editor.EnableInstancingField();                                                    // 是否启用GPU实例化(要在shader里用了multi_compile_instancing才会显示出来，实际上对应的是INSTANCING_ON关键字)
    }
}
