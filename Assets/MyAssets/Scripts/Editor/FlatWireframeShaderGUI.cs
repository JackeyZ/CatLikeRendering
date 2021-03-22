using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;


public class FlatWireframeShaderGUI : MutiPBSShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        //base.OnGUI(materialEditor, properties);
        this.target = materialEditor.target as Material;
        this.editor = materialEditor;
        this.properties = properties;
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
