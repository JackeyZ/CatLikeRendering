// 后处理-FAXX抗锯齿
// 通过混合高对比度的像素来达到抗锯齿的效果
Shader "Hidden/FAXX"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
        #include "UnityCG.cginc"
        sampler2D _MainTex;
        float4 _MainTex_TexelSize;      // 单像素占比（假如屏幕width是1080，那么_MainTex_TexelSize.x就是1/1080）
        float _ContrastThreshold;       // 对比度阈值，对比度超过该值的像素才会进行抗锯齿处理
        float _RelativeThreshold;       // 相对对比度阈值，像素附近亮度较高的时候，需要更高的对比度才进行抗锯齿处理

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

        struct LuminanceData {
            float m, n, e, s, w, ne, nw, se, sw, hightest, lowest, contrast;
        };

        struct EdgeData {
            bool isHorizontal;  // 边界是否是横向的（纵向的像素对比度高的时候说明边是横着的）
            float pixelStep;
        };

        Interpolators VertexProgram (VertexData v)
        {
            Interpolators i;
            i.pos = UnityObjectToClipPos(v.vertex);
            i.uv = v.uv;
            return i;
        }

        float4 Sample(float2 uv){
            return tex2Dlod(_MainTex, float4(uv, 0, 0));        // 不采样其他级别的mipmaps
        }

        // 得到亮度
        float SampleLuminance(float2 uv){
            #if defined(LUMINANCE_GREEN)
                return Sample(uv).g;
            #else
                return Sample(uv).a;
            #endif
        }
        // 得到亮度(uOffset：横向偏移多少个像素)(vOffset：纵向偏移多少个像素)
        float SampleLuminance(float2 uv, float uOffset, float vOffset){
            uv += _MainTex_TexelSize * float2(uOffset, vOffset);
            return SampleLuminance(uv);
        }

        // 是否需要跳过该像素，不进行抗锯齿
        bool ShouldSkipPixel(LuminanceData l){
            float threshold = max(_ContrastThreshold, _RelativeThreshold * l.hightest);
            return l.contrast < threshold;
        }

        // 得到自己以及四个邻居的像素亮度
        LuminanceData SampleLuminanceNeighborhood(float2 uv){
            LuminanceData l;
            l.m  = SampleLuminance(uv);                // 当前处理的像素的亮度
            l.n  = SampleLuminance(uv,  0,  1);        // 上方相邻的像素的亮度
            l.e  = SampleLuminance(uv,  1,  0);        // 右边相邻的像素的亮度
            l.s  = SampleLuminance(uv,  0, -1);        // 下方相邻的像素的亮度
            l.w  = SampleLuminance(uv, -1,  0);        // 左边相邻的像素的亮度
            l.ne = SampleLuminance(uv,  1,  1);        // 右上相邻的像素的亮度
            l.nw = SampleLuminance(uv, -1,  1);        // 左上相邻的像素的亮度
            l.se = SampleLuminance(uv,  1, -1);        // 右下相邻的像素的亮度
            l.sw = SampleLuminance(uv, -1, -1);        // 左上相邻的像素的亮度
            
            l.hightest = max(max(max(max(l.n, l.e), l.s), l.w), l.m);       // 算出最高亮度
            l.lowest = min(min(min(min(l.n, l.e), l.s), l.w), l.m);         // 算出最低亮度
            l.contrast = l.hightest - l.lowest;                             // 算出对比度
            return l;
        }

        // 计算混合因子(0~1)
        float DeterminePixelBlendFactor(LuminanceData l){
            float filter = 2 * (l.n + l.e + l.s + l.w);     // 相邻的权重大一点 * 2
            filter += l.ne + l.se + l.se + l.sw;            // 斜边的邻居权重小一点 * 1
            filter *= 1.0 / 12;                             // 得到一个带权重的亮度平均值
            filter = abs(filter - l.m);                     // 减去中间像素的亮度得到与周围像素的对比度
            filter = saturate(filter / l.contrast);         // 得到中间像素的亮度相对于附近亮度的比值
            float blendFactor = smoothstep(0, 1, filter);   // 做一个平滑,让线性的因子变成曲线
            return filter;
        }

        EdgeData DetermineEdge(LuminanceData l)
        {
            EdgeData e;
            float horizontal = abs(l.n + l.s - 2 * l.m) * 2 + abs(l.ne + l.se - 2 * l.e) + abs(l.nw + l.sw - 2 * l.w);      // 横向边缘权重（纵向像素的对比度，十字区域出因为距离较近，所以*2，以加大权重）
            float vertical = abs(l.e + l.w - 2 * l.m) * 2 + abs(l.ne + l.nw - 2 * l.n) + abs(l.se + l.sw - 2 * l.s);        // 纵向边缘权重
            e.isHorizontal = horizontal >= vertical;
            
            float pLuminance = e.isHorizontal ? l.n : l.e;         // 混合的正方向，如果边是横向的，则混合方向的正方向是北边
            float nLuminance = e.isHorizontal ? l.s : l.w;         // 混合的负方向，如果边是横向的，则混合方向的负方向是南边
            float pGradient = abs(pLuminance - l.m);               // 混合正方形梯度
            float nGradient = abs(nLuminance - l.m);               // 混合负方形梯度

            e.pixelStep = e.isHorizontal ? _MainTex_TexelSize.y : _MainTex_TexelSize.x;

            // 如果负方向梯度较为陡峭，则取负方向的偏移值
            if(pGradient < nGradient){
                e.pixelStep = -e.pixelStep;
            }
            return e;
        }

        float4 ApplyFXAA(float2 uv){
            LuminanceData l = SampleLuminanceNeighborhood(uv);
            // 判断是否跳过该片元，不继续抗锯齿
            if(ShouldSkipPixel(l)){
                return Sample(uv);
            }

            float pixelBlend = DeterminePixelBlendFactor(l);
            EdgeData e = DetermineEdge(l);
            if(e.isHorizontal)
            {
                uv.y += e.pixelStep * pixelBlend;
            }
            else
            {
                uv.x += e.pixelStep * pixelBlend;
            }

            return float4(Sample(uv).rgb, l.m); 
        }

    ENDCG

    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off

        Pass    // 0 计算亮度用的pass
        {
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            half4 FragmentProgram (Interpolators i) : SV_Target
            {
                half4 sample = tex2D(_MainTex, i.uv);
                sample.a = LinearRgbToLuminance(saturate(sample.rgb)); // 根据线性空间下的颜色计算亮度（0~1）， hdr下避免范围超过1，这里用saturate限制一下
                return sample;      
            }
            ENDCG
        }

        Pass    // 1 抗锯齿pass
        {
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            #pragma multi_compile _ LUMINANCE_GREEN

            half4 FragmentProgram (Interpolators i) : SV_Target
            {
                return ApplyFXAA(i.uv);
            }
            ENDCG
        }
    }
}
