using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 延迟渲染下为了支持雾效，需要挂到摄像机上的组件
/// </summary>
[ExecuteInEditMode]
public class DeferredFogEffect : MonoBehaviour
{
    public Shader deferredFog;

    [NonSerialized]
    Material fogMaterial;
    [NonSerialized]
    Camera deferredCamera;
    [NonSerialized]
    Vector3[] frustumCorners;   // 用于存储从摄像机发出的到远裁切面四个角的四条射线
    [NonSerialized]
    Vector4[] vectorArray;      // vector3转换成vector4用

    // 摄像机会在渲染场景之后调用
    [ImageEffectOpaque]     // 表示在不透明物体渲染完的时候回调,不然的话会在渲染完半透明物体才会回调
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (fogMaterial == null)
        {
            fogMaterial = new Material(deferredFog);
            frustumCorners = new Vector3[4];
            vectorArray = new Vector4[4];
            deferredCamera = GetComponent<Camera>();
        }

        if (deferredCamera.renderingPath == RenderingPath.DeferredShading)
        {
            // 计算从摄像机发出的到远裁切面四个角的四条射线
            deferredCamera.CalculateFrustumCorners(
                new Rect(0f, 0f, 1f, 1f),
                deferredCamera.farClipPlane,
                deferredCamera.stereoActiveEye,
                frustumCorners
            );

            // frustumCorners的顺序是视锥体远平面的左下角、左上角、右上角、右下角，但是后处理的四边形顶点顺序是左下角、右下角、左上角、右上角，所以这里要改下顺序赋值
            vectorArray[0] = frustumCorners[0];
            vectorArray[1] = frustumCorners[3];
            vectorArray[2] = frustumCorners[1];
            vectorArray[3] = frustumCorners[2];
            fogMaterial.SetVectorArray("_FrustumCorners", vectorArray); // 只能传Vector4给着色器

            Graphics.Blit(source, destination, fogMaterial);
        }
        else
        {
            Graphics.Blit(source, destination);
        }
    }
}
