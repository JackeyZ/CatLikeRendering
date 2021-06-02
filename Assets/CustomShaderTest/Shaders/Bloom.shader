// 辉光后处理后处理
Shader "Hidden/Bloom"         
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
        #include "UnityCG.cginc"
        sampler2D _MainTex, _SourceTex;
        float4 _MainTex_TexelSize;      // 单像素占比（假如width是1080，那么_MainTex_TexelSize.x就是1/1080）
        sampler2D _CameraDepthTexture;  // 深度缓冲区，因为是延迟渲染，所以可以用前面光照渲染时产生的深度缓冲
        float3 _FrustumCorners[4];      // 用于存储从摄像机发出的到远裁切面四个角的四条射线，由DeferrerdFogEffect.cs脚本赋值
        half4 _Filter;                  // 过滤用的各种参数，详情看BloomEffect.cs
        half _Intensity;                // 强度

        struct VertexData
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Interpolators
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        Interpolators VertexProgram (VertexData v)
        {
            Interpolators i;
            i.pos = UnityObjectToClipPos(v.vertex); // 屏幕后处理的顶点就是屏幕角上的四个点
            i.uv = v.uv;
            return i;
        }

        // 对主纹理采样（HDR的颜色用半精度（half））
        half3 Sample(float2 uv){
            return tex2D(_MainTex, uv).rgb;
        }

        // 4X4盒采样（4个 2X2像素的平均值 相加除以4）
        half3 SampleBox(float2 uv, float delta){
            float4 o = _MainTex_TexelSize.xyxy * float2(-delta, delta).xxyy; // 四个方向偏移delta个像素的uv值
            half3 s = Sample(uv + o.xy) + Sample(uv + o.zy) + Sample(uv + o.xw) + Sample(uv + o.zw);
            return s * 0.25f;
        }

        // 像素颜色过滤。亮度低于阈值的像素，颜色降低
        half3 Prefilter(half3 c){
            half brightness = max(c.r, max(c.g, c.b));                      // 颜色亮度
            // 算出软过渡曲线
            half soft = brightness - _Filter.y;
            soft = clamp(soft, 0, _Filter.z);
            soft = soft * soft * _Filter.w;

            half contribution = max(soft, brightness - _Filter.x);          // 软曲线与硬膝盖取一个最大值
            contribution /= max(brightness, 0.00001);                       // 除以原始亮度，得到亮度贡献值
            return c * contribution;
        }
    ENDCG
    
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off

        // 用于过滤掉亮度低于阈值的像素
        Pass // 0
        {      
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            float4 FragmentProgram (Interpolators i) : SV_Target
            {
                return half4(Prefilter(SampleBox(i.uv, 1)), 1);
            }
            ENDCG
        }
        
        // bloom分辨率自上而下采样用到的pass
        Pass // 1
        {      
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            float4 FragmentProgram (Interpolators i) : SV_Target
            {
                return half4(SampleBox(i.uv, 1), 1);
            }
            ENDCG
        }

        // bloom分辨率自下而上采样用到的pass
        Pass // 2
        {      
            Blend One One   // 与原图像叠加
            
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            float4 FragmentProgram (Interpolators i) : SV_Target
            {
                return half4(SampleBox(i.uv, 0.5), 1);
            }
            ENDCG
        }

        // 最后与原图像融合用的pass
        Pass // 3
        {
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            float4 FragmentProgram (Interpolators i) : SV_Target
            {
                half4 c = tex2D(_SourceTex, i.uv);
                c.rgb += _Intensity * SampleBox(i.uv, 0.5);
                return c;
            }
            ENDCG
        }

        // 调试用的pass，用来观察哪些像素会受到bloom影响
        Pass // 4
        {
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            float4 FragmentProgram (Interpolators i) : SV_Target
            {
                return half4(_Intensity * SampleBox(i.uv, 0.5), 1);
            }
            ENDCG
        }
    }
}
