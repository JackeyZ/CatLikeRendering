Shader "Custom/DeferredShading"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // 延迟渲染根据GBuffer的纹理法线等数据进行光照计算的pass
        Pass
        {
            Blend [_SrcBlend] [_DstBlend]
            //Cull Off 
            //ZTest Always
            ZWrite Off 

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram
            
            // 不支持写入多个渲染目标的平台不编译该pass，nomrt即no multiple render targets
            #pragma exclude_renderers nomrt
            #pragma multi_compile_lightpass
            #pragma multi_compile _ UNITY_HDR_ON

            #include "CustomDeferredShading.cginc"

            ENDCG
        }

        // LDR下对颜色进行-log2解码的pass, 该pass不影响HDR下的渲染
        Pass
        {
            Cull Off 
            ZWrite Off 
            ZTest Always

            // 模板测试，不要影响到天空盒渲染
            Stencil {
                Ref [_StencilNonBackground]             // 与缓冲区的值进行比较， _StencilNonBackground是Unity提供的天空盒遮罩模板
                ReadMask [_StencilNonBackground]        // 在读取stencilBufferValue的时候ReadMask会与stencilBufferValue进行按位与，得到的值再与Ref比较
                CompBack Equal                          // mesh背面渲染的时候用与模板缓冲与Ref的值相等才测试通过
                CompFront Equal                         // mesh正面渲染的时候用与模板缓冲与Ref的值相等才测试通过        
            }

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram
            
            // 不支持写入多个渲染目标的平台不编译该pass，nomrt即no multiple render targets
            #pragma exclude_renderers nomrt

            #include "UnityCG.cginc"

            sampler2D _LightBuffer;

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
                Interpolators o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 FragmentProgram (Interpolators i) : SV_Target
            {
                return -log2(tex2D(_LightBuffer, i.uv));
            }
            ENDCG
        }
    }
}
