using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 景深
/// </summary>
/// ImageEffectAllowedInSceneView:将效果应用到scene窗口
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class FXAAEffect : MonoBehaviour
{
    [HideInInspector]
    public Shader fxaaShader;    // 不在Inspector面板拖进来，直接选中脚本然后把shader拖进去

    [NonSerialized]
    Material fxaaMaterial;

    [Tooltip("对比度阈值，对比度超过该值的像素才会进行抗锯齿处理")]
    [Range(0.0312f, 0.0833f)]
    public float contrastThreshold = 0.0833f;

    [Tooltip("相对对比度阈值，像素附近亮度较高的时候，需要更高的对比度才进行抗锯齿处理")]
    [Range(0.063f, 0.333f)]
    public float relativeThreshold = 0.166f;

    [Tooltip("强度")]
    [Range(0f, 1f)]
    public float subpixelBlending = 0.75f;

    [Tooltip("是否用低品质效果")]
    public bool lowQuality = false;

    [Tooltip("是否在gamma空间中混合，若本身项目就是Gamma空间下的，则该变量无效")]
    public bool gammaBlending;
    public enum LuminanceMode { 
        /// <summary>
        /// 通过a通道来获取亮度
        /// </summary>
        Alpha, 
        /// <summary>
        /// 通过g通道来获取亮度
        /// </summary>
        Green, 
        /// <summary>
        /// 用rgb三个通道来计算亮度
        /// </summary>
        Calculate 
    }

    /// <summary>
    /// 亮度获取方式
    /// </summary>
    public LuminanceMode luminanceSource = LuminanceMode.Calculate;

    // 计算亮度的pass
    const int luminancePass = 0;
    // 抗锯齿的pass
    const int fxaaPass = 1;

    // 摄像机会在渲染场景之后调用
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if(fxaaMaterial == null)
        {
            fxaaMaterial = new Material(fxaaShader);
            fxaaMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        fxaaMaterial.SetFloat("_ContrastThreshold", contrastThreshold);
        fxaaMaterial.SetFloat("_RelativeThreshold", relativeThreshold);
        fxaaMaterial.SetFloat("_SubpixelBlending", subpixelBlending);

        if (lowQuality)
        {
            fxaaMaterial.EnableKeyword("LOW_QUALITY");
        }
        else
        {
            fxaaMaterial.DisableKeyword("LOW_QUALITY");
        }

        if (gammaBlending)
        {
            fxaaMaterial.EnableKeyword("GAMMA_BLENDING");
        }
        else
        {
            fxaaMaterial.DisableKeyword("GAMMA_BLENDING");
        }

        if (luminanceSource == LuminanceMode.Calculate)
        {
            fxaaMaterial.DisableKeyword("LUMINANCE_GREEN");
            RenderTexture luminanceTex = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);     // 用于储存带亮度贴图
            Graphics.Blit(source, luminanceTex, fxaaMaterial, luminancePass);                                           // 渲染出带亮度的贴图
            Graphics.Blit(luminanceTex, destination, fxaaMaterial, fxaaPass);
            RenderTexture.ReleaseTemporary(luminanceTex);
        }
        else
        {
            if(luminanceSource == LuminanceMode.Green)
            {
                fxaaMaterial.EnableKeyword("LUMINANCE_GREEN");
            }
            else
            {
                fxaaMaterial.DisableKeyword("LUMINANCE_GREEN");
            }
            Graphics.Blit(source, destination, fxaaMaterial, fxaaPass);
        }

    }
}
