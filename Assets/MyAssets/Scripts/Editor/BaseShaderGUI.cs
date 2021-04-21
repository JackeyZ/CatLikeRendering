using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class BaseShaderGUi : ShaderGUI
{
    protected static GUIContent staticLable = new GUIContent();
    protected Material target;
    protected MaterialEditor editor;
    MaterialProperty[] properties;
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        this.target = materialEditor.target as Material;
        this.editor = materialEditor;
        this.properties = properties;
        ThisOnGUI(materialEditor, properties);
    }

    protected virtual void ThisOnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {

    }

    /// <summary>
    /// 查找并获得材质球属性
    /// </summary>
    /// <param name="name">属性名</param>
    /// <returns></returns>
    protected MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, this.properties);
    }

    /// <summary>
    /// 记录状态快照，支持undo
    /// </summary>
    /// <param name="label"></param>
    protected void RecordAction(string label)
    {
        this.editor.RegisterPropertyChangeUndo(label);
    }

    /// <summary>
    /// 设置关键字是否激活
    /// </summary>
    /// <param name="keyword"></param>
    /// <param name="state"></param>
    protected void SetKeyword(string keyword, bool state)
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
    protected bool IsKeywordEnabled(string keyword)
    {
        return this.target.IsKeywordEnabled(keyword);
    }

    /// <summary>
    /// 获得一个文字标签
    /// </summary>
    /// <param name="text"></param>
    /// <param name="tooltip">鼠标悬停提示</param>
    /// <returns></returns>
    protected static GUIContent MakeLabel(string text, string tooltip = null)
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
    protected static GUIContent MakeLabel(MaterialProperty property, string tooltip = null)
    {
        staticLable.text = property.displayName;
        staticLable.tooltip = tooltip;
        return staticLable;
    }
}
