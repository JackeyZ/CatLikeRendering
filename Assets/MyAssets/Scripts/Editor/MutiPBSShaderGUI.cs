﻿using System.Collections;
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
    /// 半透明，只对漫反射进行半透明处理
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
            queue = RenderQueue.AlphaTest,      // 全透明cutout
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
            queue = RenderQueue.Transparent,    // 半透明，只对漫反射进行半透明处理
            renderType = "Transparent",
            srcBlend = BlendMode.One,
            dstBlend = BlendMode.OneMinusSrcAlpha,
            zWrite = false,
        },
    };
}

public class MutiPBSShaderGUI : ShaderGUI
{
    static GUIContent staticLable = new GUIContent();
    Material target;
    MaterialEditor editor;
    MaterialProperty[] properties;
    bool shouldShowAlphaCutoff;
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        //base.OnGUI(materialEditor, properties);
        this.target = materialEditor.target as Material;
        this.editor = materialEditor;
        this.properties = properties;
        DoRenderingMode();
        DoMain();
        DoSecondary();
    }

    void DoMain()
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

        DoOcclusion();

        DoEmission();

        editor.TextureScaleOffsetProperty(mainTex);
    }

    void DoRenderingMode()
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
                m.globalIlluminationFlags = MaterialGlobalIlluminationFlags.BakedEmissive;      // 让材质球的自发光参与到静态光照贴图的烘焙中
            }
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

    void DoSecondary()
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


    /// <summary>
    /// 查找并获得材质球属性
    /// </summary>
    /// <param name="name">属性名</param>
    /// <returns></returns>
    MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, this.properties);
    }

    /// <summary>
    /// 记录状态快照，支持undo
    /// </summary>
    /// <param name="label"></param>
    void RecordAction(string label)
    {
        this.editor.RegisterPropertyChangeUndo(label);
    }

    /// <summary>
    /// 设置关键字是否激活
    /// </summary>
    /// <param name="keyword"></param>
    /// <param name="state"></param>
    void SetKeyword(string keyword, bool state)
    {
        if (state)
        {
            foreach (Material target in editor.targets)
            {
                target.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material target in editor.targets)
            {
                target.DisableKeyword(keyword);
            }
        }
    }

    /// <summary>
    /// 获得某个关键字是否激活
    /// </summary>
    /// <param name="keyword"></param>
    /// <returns></returns>
    bool IsKeywordEnabled(string keyword)
    {
        return this.target.IsKeywordEnabled(keyword);
    }

    /// <summary>
    /// 获得一个GUI容器
    /// </summary>
    /// <param name="text"></param>
    /// <param name="tooltip">鼠标悬停提示</param>
    /// <returns></returns>
    static GUIContent MakeLabel(string text, string tooltip = null)
    {
        staticLable.text = text;
        staticLable.tooltip = tooltip;
        return staticLable;
    }

    /// <summary>
    /// 获得一个GUI容器
    /// </summary>
    /// <param name="property"></param>
    /// <param name="tooltip">鼠标悬停提示</param>
    /// <returns></returns>
    static GUIContent MakeLabel(MaterialProperty property, string tooltip = null)
    {
        staticLable.text = property.displayName;
        staticLable.tooltip = tooltip;
        return staticLable;
    }
}
