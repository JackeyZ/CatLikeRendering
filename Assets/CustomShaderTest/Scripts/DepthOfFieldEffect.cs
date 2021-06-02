using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 景深
/// </summary>
/// ImageEffectAllowedInSceneView:将效果应用到scene窗口
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class DepthOfFieldEffect : MonoBehaviour
{
    [Tooltip("焦距")]
    [Range(0.1f, 100f)]
    public float focusDistance = 10f;

    [Tooltip("是否自动调整焦距")]
    public bool autoTuneFocusDistance = true;

    [Range(0.5f, 10f)]
    [Tooltip("是否自动调整焦距速度")]
    public float autoTuneSpeed = 5f;

    [Tooltip("对焦范围，弥散圈将在对焦范围内（焦点附近）由0变到最大值")]
    [Range(0.1f, 10f)]
    public float focusRange = 3f;

    [Tooltip("最大弥散圈大小")]
    [Range(1f, 10f)]
    public float bokehRadius = 4f;

    [HideInInspector]
    public Shader dofShader;    // 不在Inspector面板拖进来，直接选中脚本然后把shader拖进去

    [NonSerialized]
    Material dofMaterial;

    new Camera camera;
    Vector2 screenCenterPos;

    // 渲染弥散圈用的pass（coc，通过光圈但未聚焦的投影）
    const int circleOfConfusionPass = 0;
    // 降低coc贴图的分辨率的pass(不能直接用降低目标贴图分辨率的方式来降低分辨率，因为默认的方式仅仅是对相邻像素求均值，而对于深度值或从中导出的东西（coc）不能这么做)
    const int preFilterPass = 1;
    // 散景效果的pass
    const int bokehPass = 2;
    // 后过滤
    const int postFilterPass = 3;
    // 用于处理原图像和处理后图像的融合
    const int combinePass = 4;

    // 摄像机会在渲染场景之后调用
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if(dofMaterial == null)
        {
            dofMaterial = new Material(dofShader);
            dofMaterial.hideFlags = HideFlags.HideAndDontSave;
        }
        dofMaterial.SetFloat("_FocusDistance", focusDistance);
        dofMaterial.SetFloat("_FocusRange", focusRange);
        dofMaterial.SetFloat("_BokehRadius", bokehRadius);

        // COC只有一个值，所以用RHalf单通道（有正负值）就可以了，而且不是颜色值，所以视为线性数据
        RenderTexture coc = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear);
        // 为了性能，让需要模糊的图像分辨率减半
        int width = source.width / 2;
        int height = source.height / 2;
        RenderTextureFormat format = source.format;
        RenderTexture dof0 = RenderTexture.GetTemporary(width, height, 0, format);
        RenderTexture dof1 = RenderTexture.GetTemporary(width, height, 0, format);

        dofMaterial.SetTexture("_CoCTex", coc);
        dofMaterial.SetTexture("_DoFTex", dof0);

        // 渲染出coc贴图
        Graphics.Blit(source, coc, dofMaterial, circleOfConfusionPass);
        // 合并原贴图与COC贴图，并且降低分辨率
        Graphics.Blit(source, dof0, dofMaterial, preFilterPass);
        // 渲染出模糊的散景
        Graphics.Blit(dof0, dof1, dofMaterial, bokehPass);
        // 3x3的tent高斯模糊
        Graphics.Blit(dof1, dof0, dofMaterial, postFilterPass);
        // 原图像与模糊后的图像融合，让焦点处的图像不要失真
        Graphics.Blit(source, destination, dofMaterial, combinePass);

        RenderTexture.ReleaseTemporary(coc);
        RenderTexture.ReleaseTemporary(dof0);
        RenderTexture.ReleaseTemporary(dof1);
    }

    private void Awake()
    {
    }

    private void OnEnable()
    {
        camera = GetComponent<Camera>();
        screenCenterPos = new Vector2(Screen.width / 2, Screen.height / 2);
    }

    private void Update()
    {
        // 自否自动调整焦距
        if (autoTuneFocusDistance)
        {
            float targetDistance = focusDistance;
            Ray ray;
            ray = camera.ScreenPointToRay(screenCenterPos);
            RaycastHit hit;
            if(Physics.Raycast(ray, out hit, Mathf.Infinity))
            {
                targetDistance = (hit.point - transform.position).magnitude;
            }
            focusDistance += (targetDistance - focusDistance) * Mathf.Min(1, Time.deltaTime * autoTuneSpeed);
        }
    }
}
