using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

enum TessellationMode
{
    Uniform,            // 给定一个值进行分割
    Edge,               // 根据三角面边的长度分割
}

public class TessellationShaderGUI : MutiPBSShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        //base.OnGUI(materialEditor, properties);
        this.target = materialEditor.target as Material;
        this.editor = materialEditor;
        this.properties = properties;
        DoRenderingMode();
        if (target.HasProperty("_TessellationUniform"))
        {
            DoTessellation();
        }
        DoMain();
        DoSecondary();
        DoAdvanced();
    }

    /// <summary>
    /// 曲面细分
    /// </summary>
    protected void DoTessellation()
    {
        GUILayout.Label("Tessellation", EditorStyles.boldLabel);
        EditorGUI.indentLevel += 2;                                                                                            // 缩进

        TessellationMode mode = TessellationMode.Uniform;
        if (IsKeywordEnabled("_TESSELLATION_EDGE"))
        {
            mode = TessellationMode.Edge;
        }
        EditorGUI.BeginChangeCheck();
        mode = (TessellationMode)EditorGUILayout.EnumPopup(MakeLabel("mode"), mode);
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Tessellation Mode");
            SetKeyword("_TESSELLATION_EDGE", mode == TessellationMode.Edge);
        }

        if(mode == TessellationMode.Uniform)
        {
            editor.ShaderProperty(FindProperty("_TessellationUniform"), MakeLabel("Uniform"));                                  // 细分程度
        }
        else
        {
            editor.ShaderProperty(FindProperty("_TessellationEdgeLength"), MakeLabel("Edge Length"));                           // 三角面的边每隔多远细分一次
        }

        EditorGUI.indentLevel -= 2;
    }
}
