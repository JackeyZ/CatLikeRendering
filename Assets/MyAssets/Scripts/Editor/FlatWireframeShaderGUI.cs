using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;


public class FlatWireframeShaderGUI : MutiPBSShaderGUI
{
    protected override void ThisOnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        DoRenderingMode();
        DoWirefram();
        DoMain();
        DoSecondary();
        DoAdvanced();
    }

    /// <summary>
    /// 平面与线框
    /// </summary>
    protected  void DoWirefram()
    {
        GUILayout.Label("Wireframe", EditorStyles.boldLabel);
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(FindProperty("_WireframeColor"), MakeLabel("Color"));                                     // 线框颜色
        editor.ShaderProperty(FindProperty("_WireframeSmoothing"), MakeLabel("Smoothing", "In screen space"));          // 线框过渡宽度（像素）
        editor.ShaderProperty(FindProperty("_WireframeThickness"), MakeLabel("Thickness", "In screen space"));          // 线框宽度（像素）
        EditorGUI.indentLevel -= 2;
    }
}
