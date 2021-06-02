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
        float _SubpixelBlending;

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

        // 边结构体，这里的边是指两个像素之间的空隙
        // 口口口口口口    ←边对面的像素
        // ------------    ←边
        // 口口口口口口    ←中间像素
        // ------------
        // 口口口口口口    ←像素
        struct EdgeData {
            bool isHorizontal;          // 边界是否是横向的（纵向的像素对比度高的时候说明边是横着的）
            float pixelStep;            // 单位uv偏移并且记录着边在中间像素的哪个方向（正还是负）
            float oppositeLuminance;    // 边对面的像素的亮度
            float gradient;             // 中间像素与边对面像素的亮度的差值
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
            return l.contrast < threshold;                                                  // 判断周围像素的最大对比度是否小于阈值，如果是，则不进行抗锯齿
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
            l.contrast = l.hightest - l.lowest;                             // 算出周围像素的最大对比度
            return l;
        }

        // 计算混合因子(0~1)
        float DeterminePixelBlendFactor(LuminanceData l){
            float filter = 2 * (l.n + l.e + l.s + l.w);     // 相邻的权重大一点 * 2
            filter += l.ne + l.se + l.se + l.sw;            // 斜方向的邻居权重小一点 * 1
            filter *= 1.0 / 12;                             // 得到周围的平均亮度
            filter = abs(filter - l.m);                     // 得到中间像素与周围平均亮度的差距
            filter = saturate(filter / l.contrast);         // 中间像素与周围亮度的对比度 除以 周围亮度的最大对比度
            float blendFactor = smoothstep(0, 1, filter);   // 做一个平滑,让线性的因子变成曲线
            return blendFactor * blendFactor * _SubpixelBlending;
        }
        

        #if defined(LOW_QUALITY)
            // 寻找边尽头时候采样次数
            #define EDGE_STEP_COUNT 4
            // 每步采样的距离(这里改成和unity用的一样)
            #define EDGE_STEPS 1, 1.5, 2, 4
            // 若始终没找到边的尽头，则最后对uv偏移的距离
            #define EDGE_GUESS 12
        #else
            // 寻找边尽头时候采样次数
            #define EDGE_STEP_COUNT 10
            // 每步采样的距离(这里改成和unity用的一样)
            #define EDGE_STEPS 1, 1.5, 2, 2, 2, 2, 2, 3, 3, 4  
            // 若始终没找到边的尽头，则最后对uv偏移的距离
            #define EDGE_GUESS 8
        #endif

        static const float edgeSteps[EDGE_STEP_COUNT] = {EDGE_STEPS};

        // 计算边混合因子（0~0.5）,像素越靠近边的尽头，该因子越接近0
        float DetermineEdgeBlendFactor(LuminanceData l, EdgeData e, float2 uv){
            float2 uvEdge = uv;                                 // 中间像素的uv
            float2 edgeStep;                                    // 沿着边缘方向的单次采样偏移，横边沿着x轴，纵边沿着y轴
            // 如果边是横着的
            if(e.isHorizontal)
            {
                uvEdge.y += e.pixelStep * 0.5;                  // uv往上或下偏移半个单位uv，让uv坐标落在边上，后面采样的话可以直接取到两个像素的平均值
                edgeStep = float2(_MainTex_TexelSize.x, 0);
            }
            else
            {
                uvEdge.x += e.pixelStep * 0.5;
                edgeStep = float2(0, _MainTex_TexelSize.y);
            }

            float edgeLuminance = (l.m + e.oppositeLuminance) * 0.5;        // 边的亮度（中间像素与边对面的像素的平均亮度）
            float gradientThreshold = e.gradient * 0.25;                    // 亮度差值（中间像素与边对面的像素的亮度的差值）的0.25倍

            
            // 沿着边的uv正方向（横向边沿着x方向，纵向变则沿着y方向）遍历，直到找到边的尽头，最多遍历9次
            float2 puv = uvEdge + edgeStep * edgeSteps[0];
            float pLuminanceDelta = SampleLuminance(puv) - edgeLuminance;   // 采样点与原始相似平均亮度的差
            bool pAtEnd = abs(pLuminanceDelta) >= gradientThreshold;        // 当亮度差距比较大的啥时候，就当做是找到了边尽头

            UNITY_UNROLL                                                    // 展开循环，优化性能
            for(int i = 1; i < EDGE_STEP_COUNT && !pAtEnd; i++){
                puv += edgeStep * edgeSteps[i];
                pLuminanceDelta = SampleLuminance(puv) - edgeLuminance;
                pAtEnd = abs(pLuminanceDelta) >= gradientThreshold;
            }
            if(!pAtEnd){
                puv += edgeStep * EDGE_GUESS;                               // 如果始终找不到边的尽头，则uv多偏移一点
            }
            
            // 沿着边的uv负方向（横向边沿着x方向，纵向变则沿着y方向）遍历，直到找到边的尽头，最多遍历9次
            float2 nuv = uvEdge - edgeStep * edgeSteps[0];
            float nLuminanceDelta = SampleLuminance(nuv) - edgeLuminance;   // 采样点与原始相似平均亮度的差
            bool nAtEnd = abs(nLuminanceDelta) >= gradientThreshold;        // 当亮度差距比较大的时候，就当做是找到了边尽头

            UNITY_UNROLL
            for(int j = 1; j < EDGE_STEP_COUNT && !nAtEnd; j++){
                nuv -= edgeStep * edgeSteps[j];
                nLuminanceDelta = SampleLuminance(nuv) - edgeLuminance;
                nAtEnd = abs(nLuminanceDelta) >= gradientThreshold;
            }
            if(!nAtEnd){
                nuv -= edgeStep * EDGE_GUESS;                               // 如果始终找不到边的尽头，则uv多偏移一点
            }


            float pDistance, nDistance;                                     // 边的尽头与中间像素（当前处理的像素）的uv相差多少
            if(e.isHorizontal){
                pDistance = puv.x - uv.x;    
                nDistance = uv.x - nuv.x;
            }
            else
            {
                pDistance = puv.y - uv.y;
                nDistance = uv.y - nuv.y;
            }

            float shortestDistance;                                          // 取最小值
            bool deltaSign;                                                  // 布尔值，用于储存边尽头像素的亮度是否比中间像素亮
            if(pDistance <= nDistance){
                shortestDistance = pDistance;
                deltaSign = pLuminanceDelta >= 0;
            }
            else
            {
                shortestDistance = nDistance;
                deltaSign = nLuminanceDelta >= 0;
            }

            // 跳过其中一侧，只取一个方向融合，避免重复融合同一条边的两侧
            if(deltaSign == (l.m - edgeLuminance >= 0)){
                return 0;
            }

            float edgeLength = pDistance + nDistance;
            return 0.5 - shortestDistance / edgeLength;         // 返回一个0~0.5的值,当前中间像素越靠近边的尽头，则返回值越接近0 
        }

        // 确定边缘, 返回边数据
        EdgeData DetermineEdge(LuminanceData l)
        {
            EdgeData e;
            float horizontal = abs(l.n + l.s - 2 * l.m) * 2 + abs(l.ne + l.se - 2 * l.e) + abs(l.nw + l.sw - 2 * l.w);      // 横向边缘权重（纵向像素的对比度，十字区域出因为距离较近，所以*2，以加大权重）
            float vertical = abs(l.e + l.w - 2 * l.m) * 2 + abs(l.ne + l.nw - 2 * l.n) + abs(l.se + l.sw - 2 * l.s);        // 纵向边缘权重
            e.isHorizontal = horizontal >= vertical;
            
            float pLuminance = e.isHorizontal ? l.n : l.e;         // 混合的正方向，如果边是横向的，则混合方向的正方向是北边
            float nLuminance = e.isHorizontal ? l.s : l.w;         // 混合的负方向，如果边是横向的，则混合方向的负方向是南边
            float pGradient = abs(pLuminance - l.m);               // 混合正方向梯度
            float nGradient = abs(nLuminance - l.m);               // 混合负方向梯度

            e.pixelStep = e.isHorizontal ? _MainTex_TexelSize.y : _MainTex_TexelSize.x;

            // 如果负方向梯度较为陡峭，则表明边在负方向上，取负方向的偏移值
            if(pGradient < nGradient){
                e.pixelStep = -e.pixelStep;
                e.oppositeLuminance = nLuminance;                  // 得到边对面的像素的亮度
                e.gradient = nGradient;                            // 边对面的像素的亮度与中间像素亮度差值
            }
            else
            {
                e.oppositeLuminance = pLuminance;
                e.gradient = pGradient;
            }
            return e;
        }

        float4 ApplyFXAA(float2 uv){
            LuminanceData l = SampleLuminanceNeighborhood(uv);
            // 判断是否跳过该片元，不进行抗锯齿
            if(ShouldSkipPixel(l)){
                return Sample(uv);
            }

            float pixelBlend = DeterminePixelBlendFactor(l);       // 3x3混合因子，当中间像素亮度与周围像素的平均亮度差距较大的时候，该值接近1
            EdgeData e = DetermineEdge(l);                         // 边数据
            float edgeBlend = DetermineEdgeBlendFactor(l, e, uv);  // 边混合因子，当前中间像素越靠近边的尽头，则返回值越接近0 
            float finalBlend = max(pixelBlend, edgeBlend);         // 两种混合因子取一个最大值


            // 判断边是否是横边
            if(e.isHorizontal)
            {
                uv.y += e.pixelStep * finalBlend;
            }
            else
            {
                uv.x += e.pixelStep * finalBlend;
            }

            return float4(Sample(uv).rgb, l.m);                    // 把中间像素的亮度作为第四个分量返回出去
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

            #pragma multi_compile _ GAMMA_BLENDING

            half4 FragmentProgram (Interpolators i) : SV_Target
            {
                half4 sample = tex2D(_MainTex, i.uv);
                sample.rgb = saturate(sample.rgb);           // 限定rgb的颜色到0~1，因为后续fxaa会融合旁边像素的颜色，这里可以避免LDR的颜色和HDR颜色进行混合的时候，原本LDR的像素变成了HDR
                half3 linearSample = sample.rgb;
                // 判断当前项目是否处于gamma颜色空间
                #if defined(UNITY_COLORSPACE_GAMMA) 
                    linearSample = GammaToLinearSpace(sample.rgb);
                #endif 
                sample.a = LinearRgbToLuminance(linearSample); // 根据线性空间下的颜色计算亮度（0~1）， hdr下避免范围超过1，这里用saturate限制一下
                
                // 判断是否需要在Gamma空间下进行混合
                #if defined(GAMMA_BLENDING)
                    // 若当前项目使用的是Gamma空间，则没必要转换了
                    #if !defined(UNITY_COLORSPACE_GAMMA)
                        sample.rgb = LinearToGammaSpace(sample.rgb);
                    #endif
                #endif
                return sample;      
            }
            ENDCG
        }

        Pass    // 1 抗锯齿pass
        {
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            // 是否把g通道作为亮度（不用自己额外计算亮度，比较省性能）
            #pragma multi_compile _ LUMINANCE_GREEN
            // 是否用较低品质的抗锯齿
            #pragma multi_compile _ LOW_QUALITY
            // 是否在gamma空间下混合
            #pragma multi_compile _ GAMMA_BLENDING

            half4 FragmentProgram (Interpolators i) : SV_Target
            {
                float4 sample = ApplyFXAA(i.uv);
                
                // 如果项目用的是线性空间，这里转换到线性空间返回
                #if !defined(UNITY_COLORSPACE_GAMMA)
                    #if defined(GAMMA_BLENDING)
                        sample.rgb = GammaToLinearSpace(sample.rgb);    
                    #endif
                #endif
                return sample;
            }
            ENDCG
        }
    }
}
