// 后处理-景深
Shader "Hidden/DepthOfField"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
        #include "UnityCG.cginc"
        sampler2D _MainTex, _CameraDepthTexture;
        sampler2D _CoCTex;              // coc贴图,存储着每个像素的弥散圈半径
        sampler2D _DoFTex;              // 前几个pass模糊后的景深图像
        float4 _MainTex_TexelSize;      // 单像素占比（假如屏幕width是1080，那么_MainTex_TexelSize.x就是1/1080）

        float _FocusDistance;           // 焦距 
        float _FocusRange;              // 对焦范围，弥散圈将在对焦范围内（焦点附近）由0变到最大值
        float _BokehRadius;             // 最大弥散圈半径

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
            i.pos = UnityObjectToClipPos(v.vertex);
            i.uv = v.uv;
            return i;
        }

    ENDCG

    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off

        Pass    // 0 用于渲染出一张记录每个像素点弥散圈（coc）大小的贴图
        {
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            half FragmentProgram (Interpolators i) : SV_Target
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);      // 采样深度
                depth = LinearEyeDepth(depth);                                      // 转换成view空间下的正的z值
                float coc = (depth - _FocusDistance) / _FocusRange;                 // 计算弥散圈大小(近似计算)
                coc = clamp(coc, -1, 1) * _BokehRadius;                             // 弥散圈限制到-1到1,负的弥散圈表示片元的深度比焦距近。最后用散景半径（最大弥散圈半径）进行缩放
                return coc;
            }
            ENDCG
        }

        Pass    // 1 用于降低coc贴图的分辨率
        {
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            // 计算权重，减弱散景的强度，避免太大的改变图像的整体亮度
            half Weigh(half3 c){
                return 1 / (1 + max(max(c.r, c.g), c.b));
            }

            half4 FragmentProgram (Interpolators i) : SV_Target
            {
                float4 o = _MainTex_TexelSize.xyxy * float2(-0.5, 0.5).xxyy;        // 0.5个单位的uv偏移值
                
                half3 s0 = tex2D(_MainTex, i.uv + o.xy).rgb;
                half3 s1 = tex2D(_MainTex, i.uv + o.zy).rgb;
                half3 s2 = tex2D(_MainTex, i.uv + o.xw).rgb;
                half3 s3 = tex2D(_MainTex, i.uv + o.zw).rgb;
                half w0 = Weigh(s0);
                half w1 = Weigh(s1);
                half w2 = Weigh(s2); 
                half w3 = Weigh(s3);
                half3 color = s0 * w0 + s1 * w1 + s2 * w2 + s3 * w3;
                color /= max(w0 + w1 + w2 + w3, 0.00001);

                half coc0 = tex2D(_CoCTex, i.uv + o.xy).r;                          // 左下
                half coc1 = tex2D(_CoCTex, i.uv + o.zy).r;                          // 右下
                half coc2 = tex2D(_CoCTex, i.uv + o.xw).r;                          // 左上
                half coc3 = tex2D(_CoCTex, i.uv + o.zw).r;                          // 右上
                
                // 四个像素里选一个弥散圈（coc）最大的
                half cocMin = min(coc0, min(coc1, min(coc2, coc3)));
                half cocMax = max(coc0, max(coc1, max(coc2, coc3)));
                half coc = cocMax >= -cocMin ? cocMax : cocMin;                     // 取绝对值最大的
                return half4(color, coc);
            }
            ENDCG
        }

        Pass {   //2 散景效果
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram
            #define KERNEL_MEDIUM

            // From https://github.com/Unity-Technologies/PostProcessing/blob/v2/PostProcessing/Shaders/Builtins/DiskKernels.hlsl
            // uv偏移量
            #if defined(KERNEL_SMALL)
            // rings = 2
            // points per ring = 5
            static const int kSampleCount = 16;
            static const float2 kDiskKernel[kSampleCount] = {
                float2(0,0),
                float2(0.54545456,0),
                float2(0.16855472,0.5187581),
                float2(-0.44128203,0.3206101),
                float2(-0.44128197,-0.3206102),
                float2(0.1685548,-0.5187581),
                float2(1,0),
                float2(0.809017,0.58778524),
                float2(0.30901697,0.95105654),
                float2(-0.30901703,0.9510565),
                float2(-0.80901706,0.5877852),
                float2(-1,0),
                float2(-0.80901694,-0.58778536),
                float2(-0.30901664,-0.9510566),
                float2(0.30901712,-0.9510565),
                float2(0.80901694,-0.5877853),
            };
            #endif

            #if defined(KERNEL_MEDIUM)
            // rings = 3
            // points per ring = 7
            static const int kSampleCount = 22;
            static const float2 kDiskKernel[kSampleCount] = {
                float2(0,0),
                float2(0.53333336,0),
                float2(0.3325279,0.4169768),
                float2(-0.11867785,0.5199616),
                float2(-0.48051673,0.2314047),
                float2(-0.48051673,-0.23140468),
                float2(-0.11867763,-0.51996166),
                float2(0.33252785,-0.4169769),
                float2(1,0),
                float2(0.90096885,0.43388376),
                float2(0.6234898,0.7818315),
                float2(0.22252098,0.9749279),
                float2(-0.22252095,0.9749279),
                float2(-0.62349,0.7818314),
                float2(-0.90096885,0.43388382),
                float2(-1,0),
                float2(-0.90096885,-0.43388376),
                float2(-0.6234896,-0.7818316),
                float2(-0.22252055,-0.974928),
                float2(0.2225215,-0.9749278),
                float2(0.6234897,-0.7818316),
                float2(0.90096885,-0.43388376),
            };
            #endif

            // coc是当前像素对应的弥散圈半径，radius是采样uv的偏移值长度，当radius大于coc的时候表示偏移超出了coc范围，此时根据超出的多或少来平滑降低权重
            half Weigh(half coc, half radius){
                return saturate((coc - radius + 2) / 2);            // saturate把值限制到0~1， 
            }

            half4 FragmentProgram(Interpolators i) : SV_Target
            {
                half3 bgColor = 0;                                  // 用于储存背景（超过焦距的像素）散射后的颜色
                half bgWeight = 0;
                half3 fgColor = 0;                                  // 用于储存前景（小于焦距的像素）散射后的颜色，前景和背景分开储存的为了避免前景与背景的像素很靠近的时候，在进行模糊时，会采样到二者的颜色
                half fgWeight = 0;

                // 用DiskKernel.hlsl中定义的针对景深用的uv偏移量数组进行采样，再求平均值。
                // 遍历像素周围的一圈，进行采样，求均值
                for(int k = 0; k < kSampleCount; k++){
                    float2 o = kDiskKernel[k] * _BokehRadius;
                    half radius = length(o);                                // 偏移量长度（散圈的半径）
                    o *= _MainTex_TexelSize.xy;
                    half4 s = tex2D(_MainTex, i.uv + o);
                    half coc = s.a;                                         // a通道存储着当前像素的弥散圈半径

                    // 偏移量过大的话平滑过渡，降低权重
                    half bgw = Weigh(max(0, coc), radius);                  // max(0, coc)：背景采样权重
                    bgColor += s.rgb * bgw;                                 // 根据权重融合颜色
                    bgWeight += bgw;                                        // 把权重记录下来，后续求均值
                    
                    // 偏移量过大的话平滑过渡，降低权重
                    half fgw = Weigh(-coc, radius);                         // -coc：前景采样权重
                    fgColor += s.rgb * fgw;                                 // 根据权重融合颜色
                    fgWeight += fgw;                                        // 把权重记录下来，后续求均值
                }
                bgColor *= 1.0 / (bgWeight + (bgWeight == 0));
                fgColor *= 1.0 / (fgWeight + (fgWeight == 0));
                half bgfg = min(1, fgWeight * 3.14159265359 / kSampleCount);// 用于储存当前像素位于前景还是背景，0表示位于背景，0~1在二者之间，大于1表示位于前景
                                                                            // 若fgWeight至少有一个采样点，则表明位于前景，bgfg取1，后续插值直接用前景的颜色
                half3 color = lerp(bgColor, fgColor, bgfg);
                return half4(color, bgfg);
            }

            ENDCG
        }

        Pass    // 3 后过滤，3x3的盒式tent滤波器
        { 
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram
            half4 FragmentProgram(Interpolators i) : SV_Target {
                float4 o = _MainTex_TexelSize.xyxy * float2(-0.5, 0.5).xxyy;
                // 左下右下左上右上，四个方向偏移0.5个像素采样，求平均
                half4 s = tex2D(_MainTex, i.uv + o.xy) +                            // 由于uv偏移了0.5个单位采样，所以刚好嵌在四个像素的中间，最后会是这四个像素的平均值
                            tex2D(_MainTex, i.uv + o.zy) +
                            tex2D(_MainTex, i.uv + o.xw) +
                            tex2D(_MainTex, i.uv + o.zw);
                return s * 0.25;
            }
            ENDCG
        }

        Pass    // 4 原图像与景深图形融合，让焦点处的像素不要失真
        {   
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            half4 FragmentProgram (Interpolators i) : SV_Target
            {
                half4 source = tex2D(_MainTex, i.uv);                       // 原图像的像素值
                half coc = tex2D(_CoCTex, i.uv).r;                          // 弥散圈半径（coc），负值表示像素比焦点近，正值表示比焦点远
                half4 dof = tex2D(_DoFTex, i.uv);                           // 采样处理后的图像
                half dofStrength = smoothstep(0.1, 1, abs(coc));            // 相当于到背景的过渡值，弥散圈平滑成0~1，若像素位于焦距区域(abs(coc)<0.1)，则取0，若像素位于背景或前景，则取1。但这里前景过渡值一般用不上，用下面的bgfg才是真的前景过渡值，这里加上abs是为了保存一个前景过渡值给bgfg兜底，当bgfg失效的时候还可以用本变量。
                half bgfg = dof.a;                                          // 相当于到前景的过渡值，a通道储存这当前像素位于前景还是背景，大于1表示在前景
                // 在原图像与景深图像之间做插值，无论是dofStrength接近1，还是bgfg接近1，都取接近dof的值
                half3 color = lerp(source.rgb, dof.rgb, dofStrength + (1 - dofStrength) * bgfg);       
                return half4(color, source.a);
            }
            ENDCG
        }
    }
}
