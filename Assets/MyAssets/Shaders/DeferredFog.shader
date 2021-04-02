// 延迟渲染模式下的雾效后处理
Shader "Hidden/DeferredFog"         
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            // 雾效(三关键字FOG_LINEAR,FOG_EXP,FOG_EXP2)对应Lighting window - Other Setting - Fog - Mode
            #pragma multi_compile_fog

            // 表明基于距离来计算雾浓度,如果不定义则基于深度
            //#define FOG_DISTANCE
            // 雾效是否影响天空盒
            //#define FOG_SKYBOX

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;  // 深度缓冲区，因为是延迟渲染，所以可以用前面光照渲染时产生的深度缓冲
            float3 _FrustumCorners[4];      // 用于存储从摄像机发出的到远裁切面四个角的四条射线，由DeferrerdFogEffect.cs脚本赋值

            struct VertexData
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                    
                // 是否基于距离计算雾浓度
                #if defined(FOG_DISTANCE)
                    float3 ray : TEXCOORD1;
                #endif
            };

            Interpolators VertexProgram (VertexData v)
            {
                Interpolators o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                #if defined(FOG_DISTANCE)
                    o.ray = _FrustumCorners[v.uv.x + 2 * v.uv.y]; // 利用uv来计算元平面四个角的index， uv坐标分别是(0, 0),(1, 0),(0, 1),(1, 1)
                #endif
                return o;
            }

            float4 FragmentProgram (Interpolators i) : SV_Target
            {
                float3 sourceColor = tex2D(_MainTex, i.uv).rgb;
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);                      // SAMPLE_DEPTH_TEXTURE会帮助我们根据不同平台对深度图进行采样
                depth = Linear01Depth(depth);                                                       // 深度缓冲区里的深度与实际片元的z值并不是线性关系，通过Linear01Depth转换成线性关系
                float viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y;             // 用0~1的深度乘far - near，得到视口空间下片元到近裁切面的z方向上的距离

                // 判断是否用距离来计算雾浓度
                #if defined(FOG_DISTANCE)
                    viewDistance = length(i.ray * depth);
                #endif
                UNITY_CALC_FOG_FACTOR_RAW(viewDistance);                                            // 根据距离算出雾效因子unityFogFactor
                unityFogFactor = saturate(unityFogFactor);
                // 判断雾效是否不需要影响天空盒
                #if !defined(FOG_SKYBOX)
                    if(depth > 0.9999){
                        unityFogFactor = 1;
                    }
                #endif

                // 判断雾效是否未开启
                #if !defined(FOG_LINEAR) && !defined(FOG_EXP) && !defined(FOG_EXP2)
                    unityFogFactor = 1;
                #endif

                float3 foggedColor = lerp(unity_FogColor.rgb, sourceColor, unityFogFactor);         // 根据算出来的雾效因子插值得到颜色，

                
                return float4(foggedColor, 1);
            }
            ENDCG
        }
    }
}
