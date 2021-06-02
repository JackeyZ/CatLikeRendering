// 三向贴图GUI
using UnityEngine;
using UnityEditor;

public class TriplanarShaderGUI : BaseShaderGUi
{
    protected override void ThisOnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        editor.ShaderProperty(FindProperty("_MapScale"), MakeLabel("MapScale", "贴图采样缩放"));
        DoMaps();
        DoBlending();
        DoOtherSettings();
    }
    void DoMaps()
    {
        GUILayout.Label("Top Maps", EditorStyles.boldLabel);
        MaterialProperty topAlbedo = FindProperty("_TopMainTex");
        Texture topTexture = topAlbedo.textureValue;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel("Albedo"), topAlbedo);
        // 如果上方反射率贴图更变了
        if (EditorGUI.EndChangeCheck() && topTexture != topAlbedo.textureValue) 
        {
            // 如果存在顶部反射率贴图，则把对应关键字激活
            SetKeyword("_SEPARATE_TOP_MAPS", topAlbedo.textureValue);
        }
        editor.TexturePropertySingleLine(MakeLabel("MOHS", "Metallic(R) Occlusion(G) Height(B) Smoothness(A)"), FindProperty("_TopMOHSMap"));
        editor.TexturePropertySingleLine(MakeLabel("Normals"), FindProperty("_TopNormalMap"));


        GUILayout.Label("Maps", EditorStyles.boldLabel);
        editor.TexturePropertySingleLine(MakeLabel("Albedo"), FindProperty("_MainTex"));
        editor.TexturePropertySingleLine(MakeLabel("MOHS", "Metallic(R) Occlusion(G) Height(B) Smoothness(A)"), FindProperty("_MOHSMap"));
        editor.TexturePropertySingleLine(MakeLabel("Normals"), FindProperty("_NormalMap"));
    }

    void DoBlending()
    {
        GUILayout.Label("Blending", EditorStyles.boldLabel);
        editor.ShaderProperty(FindProperty("_BlendOffset"), MakeLabel("BlendOffset", "混合偏移"));
        editor.ShaderProperty(FindProperty("_BlendExponent"), MakeLabel("BlendExponent", "混合指数缩放"));
        editor.ShaderProperty(FindProperty("_BlendHeightStrength"), MakeLabel("BlendHeightStrength", "高度图混合强度"));
    }

    void DoOtherSettings() 
    {
        GUILayout.Label("Other Settings", EditorStyles.boldLabel);
        editor.RenderQueueField();
        editor.EnableInstancingField();
    }
}
