using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 辉光
/// 实现思路：
/// 1、用一个pass过滤掉摄像机源图像里面亮度低于阈值的像素
/// 2、根据迭代次数逐级对图像的分辨率进行减半模糊，并把每级的模糊图像存起来
/// 3、根据迭代次数逐级对最模糊的图像的分辨率进行加倍，并在shader里与之前的同分辨率的模糊图像进行叠加
/// 4、最后用一个pass把上面第三步最终得到的图像与摄像机源图像进行叠加，从而产生辉光
/// </summary>
/// ImageEffectAllowedInSceneView:将辉光效果应用到scene窗口
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class BloomEffect : MonoBehaviour
{
    public Shader bloomShader;

    [Tooltip("强度")]
    [Range(0, 10)]
    public float intensity = 1;

    [Tooltip("模糊迭代次数")]
    [Range(1, 16)]
    public int iterations = 1;

    [Tooltip("亮度阈值,高于该亮度的像素才产生辉光")]
    [Range(0, 10)]
    public float threshold = 1;

    [Tooltip("亮度阈值过渡的柔和程度")]
    [Range(0, 1)]
    public float softThreshold = 0.5f;

    [Tooltip("调试用，便于观察哪些像素会受到bloom影响")]
    public bool debug = false;

    [NonSerialized]
    Material bloomMat;

    const int BoxDownPrefilterPass = 0; // 过滤掉亮度低于阈值的像素的pass
    const int BoxDownPass = 1;          // 逐级递减的时候用哪个pass
    const int BoxUpPass = 2;            // 逐级递增的时候用哪个pass
    const int ApplyBloomPass = 3;       // 最后与原图像融合用的pass
    const int DebugBloomPass = 4;       // 调试用的pass，用来观察哪些像素会受到bloom影响

    // 摄像机会在渲染场景之后调用
    [ImageEffectOpaque]     // 表示在不透明物体渲染完的时候回调,不然的话会在渲染完半透明物体才会回调
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if(bloomMat == null)
        {
            bloomMat = new Material(bloomShader);
            bloomMat.hideFlags = HideFlags.HideAndDontSave;
        }

        float knee = threshold * softThreshold;
        Vector4 filter;
        filter.x = threshold;
        filter.y = filter.x - knee;
        filter.z = 2f * knee;
        filter.w = 0.25f / (knee + 0.00001f);
        bloomMat.SetVector("_Filter", filter);
        bloomMat.SetFloat("_Intensity", intensity);

        int width = source.width / 2;
        int height = source.height / 2;
        RenderTextureFormat format = source.format;

        RenderTexture[] textures = new RenderTexture[16];

        RenderTexture currentDestination = textures[0] = RenderTexture.GetTemporary(width, height, 0, format); // 因为我们需要用HDR，所以第四个参数用源数据的格式
        Graphics.Blit(source, currentDestination, bloomMat, BoxDownPrefilterPass);
        RenderTexture currentSource = currentDestination;
        int i = 1;
        // 分辨率逐级减半
        for (i = 1; i < iterations; i++)
        {
            width /= 2;
            height /= 2;
            if(height < 2)
            {
                break;
            }
            currentDestination = textures[i] = RenderTexture.GetTemporary(width, height, 0, format);
            Graphics.Blit(currentSource, currentDestination, bloomMat, BoxDownPass);
            currentSource = currentDestination;
        }

        // 分辨率逐级递增
        for (i -= 2; i >= 0; i--)
        {
            currentDestination = textures[i];
            textures[i] = null;
            Graphics.Blit(currentSource, currentDestination, bloomMat, BoxUpPass);
            RenderTexture.ReleaseTemporary(currentSource);
            currentSource = currentDestination;
        }
        if (debug)
        {
            Graphics.Blit(currentSource, destination, bloomMat, DebugBloomPass);
        }
        else
        {
            bloomMat.SetTexture("_SourceTex", source);
            Graphics.Blit(currentSource, destination, bloomMat, ApplyBloomPass);
        }
         

        RenderTexture.ReleaseTemporary(currentSource);
    }
}
