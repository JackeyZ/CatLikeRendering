// 
// ���ű����CustomLighting���õ������нṹ�塢������Get����
//
#if !defined(CUSTOM_LIGHTING_INPUT_INLCUDE)
#define CUSTOM_LIGHTING_INPUT_INLCUDE

// �����ȡ�����ʵķ���û�б������ط����壬����GetAlbedo��Ϊ��ȡ�����ʵķ��������������ط���д�÷�����
#if !defined(ALBEDO_FUNCTION)
    #define ALBEDO_FUNCTION GetAlbedo
#endif

// UnityPBSLighting��Ҫ�ŵ�AutoLight֮ǰ
#include "UnityPBSLighting.cginc"           
#include "AutoLight.cginc"

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #if !defined(FOG_DISTANCE)
        #define FOG_DEPTH 1
    #endif
    #define FOG_ON 1
#endif
 
// ����VertexData�������ߡ�uv1��uv2����ϸ����ɫ���е���Ҫ�õ�
#define TESSELLATION_TANGENT 1
#define TESSELLATION_UV1 1
#define TESSELLATION_UV2 1

#if defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
    #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK)
        // ���������ǻ�Ϲ�ģʽ������ģʽ��Subtractive Mod���µľ�̬����, ��̬���岻�ᶨ��LIGHTMAP_ON
        #define SUBTRACTIVE_LIGHT 1 
    #endif
#endif


// ���ʹ���Ӳ���ͼ�������ö���ƫ��
#if defined(_PARALLAX_MAP) && defined(VERTEX_DISPLACEMENT_INSTEAD_OF_PARALLAX)
    // ȡ��ʹ��uv���Ӳ�ƫ��
    #undef _PARALLAX_MAP               
    // ���ö���ƫ��
    #define VERTEX_DISPLACEMENT 1       
    // ���Ӳ���ͼ�ı���Ū���±�������ϸ����ɫ������
    #define _DisplacementMap _ParallaxMap
    // ���Ӳ�ǿ��Ū���±�������ϸ����ɫ������
    #define _DisplacementStrength _ParallaxStrength
#endif

// ���㺯������
struct VertexData
{
    UNITY_VERTEX_INPUT_INSTANCE_ID                      // ʵ��ID , ��һ��uint����ͬƽ̨����᲻ͬ�����忴Դ�룬֧��GPUInstance 
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;                             // ��̬������ͼuv��LIGHTMAP_ON�ؼ������õ�ʱ����Ч��
    float2 uv2 : TEXCOORD2;                             // ��̬������ͼuv��DYNAMICLIGHTMAP_ON�ؼ������õ�ʱ����Ч��
};

// ���㺯�����
struct InterpolatorsVertex
{
    UNITY_VERTEX_INPUT_INSTANCE_ID                      // ʵ��ID , ��һ��uint����ͬƽ̨����᲻ͬ�����忴Դ�룬֧��GPUInstance 
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;                          // ����ռ䷨��

    // �ж��Ƿ���ƬԪ�������㸱����
    #if defined(BINORMAL_PER_FRAGMENT)
        float4 tangent : TEXCOORD2;
    // �������ƬԪ�������㣬���ڶ��㺯����ø����߲�ֵ������
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif

    // ��������������
    #if FOG_DEPTH
        float4 worldPos : TEXCOORD4;
    #else
        float3 worldPos : TEXCOORD4;
    #endif
    float4 pos : SV_POSITION;                         // �ü����꣬д������Ϊpos���TRANSFER_SHADOWʹ��

    // �ж��Ƿ�������Ӱ����
    //#if defined(SHADOWS_SCREEN)
    //    float4 shadowCoordinates : TEXCOORD5;       // ��Ӱ��ͼuv����
    //#endif
    // ������Ӱ��ͼuv���꣬����5��ʾ����TEXCOORD5
    //SHADOW_COORDS(5)
    // ������Ӱ��ͼuv���꣬����5��ʾ����TEXCOORD5
	UNITY_SHADOW_COORDS(5)

    // �ж��Ƿ����˶����Դ
    #if defined(VERTEXLIGHT_ON) 
        float3 vertexLightColor : TEXCOORD6;
    #endif

    // �ж��Ƿ�ʹ�þ�̬������ͼ
    #if defined(LIGHTMAP_ON) 
        float2 lightmapUV : TEXCOORD6;                 // ������ͼuv���붥����ջ��⣬��������Ҳʹ��TEXCOORD6
    #endif

    // �ж��Ƿ������˶�̬������ͼ                      // ��ѡLighting -> Realtime Lighting -> Realtime Global Illumination��Ч
    #if defined(DYNAMICLIGHTMAP_ON)
        float2 dynamicLightmapUV : TEXCOORD7;
    #endif

    #if defined(_PARALLAX_MAP)
        float3 tangentViewDir : TEXCOORD8;               // �����������߿ռ��µ����߷���ƬԪָ���������������
    #endif
};

// ƬԪ��������
struct Interpolators
{
    UNITY_VERTEX_INPUT_INSTANCE_ID                      // ʵ��ID , ��һ��uint����ͬƽ̨����᲻ͬ�����忴Դ�룬֧��GPUInstance 
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;                          // ����ռ䷨��

    // �ж��Ƿ���ƬԪ�������㸱����
    #if defined(BINORMAL_PER_FRAGMENT)
        float4 tangent : TEXCOORD2;
    // �������ƬԪ�������㣬���ڶ��㺯����ø����߲�ֵ������
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif

    // ��������������
    #if FOG_DEPTH
        float4 worldPos : TEXCOORD4;
    #else
        float3 worldPos : TEXCOORD4;
    #endif

    // �ж��Ƿ�������LOD���뵭��
    #if defined(LOD_FADE_CROSSFADE)
        UNITY_VPOS_TYPE vpos : VPOS;                      // ��Ļ�ռ�����(x �� [0, width]�� y �� [0, height])����ΪƬԪ��ɫ�������ʱ��������SV_POSITION��һ���ģ�������Ļ�ռ�����,  UNITY_VPOS_TYPE���൱��float4, DX9��float2
    #else
        float4 pos : SV_POSITION;                         // ��Ϊ������ɫ�������ʱ���ǲü����꣬д������Ϊpos���TRANSFER_SHADOWʹ�ã���ΪƬԪ��ɫ�������ʱ������Ļ���꣬��������0.5��ƫ����ѡ����������
    #endif

    // �ж��Ƿ�������Ӱ����
    //#if defined(SHADOWS_SCREEN)
    //    float4 shadowCoordinates : TEXCOORD5;       // ��Ӱ��ͼuv����
    //#endif
    // ������Ӱ��ͼuv���꣬����5��ʾ����TEXCOORD5
    //SHADOW_COORDS(5)
    // ������Ӱ��ͼuv���꣬����5��ʾ����TEXCOORD5
	UNITY_SHADOW_COORDS(5)

    // �ж��Ƿ����˶����Դ
    #if defined(VERTEXLIGHT_ON) 
        float3 vertexLightColor : TEXCOORD6;
    #endif

    // �ж��Ƿ�ʹ�þ�̬������ͼ
    #if defined(LIGHTMAP_ON) 
        float2 lightmapUV : TEXCOORD6;                 // ������ͼuv���붥����ջ��⣬��������Ҳʹ��TEXCOORD6
    #endif

    // �ж��Ƿ������˶�̬������ͼ                      // ��ѡLighting -> Realtime Lighting -> Realtime Global Illumination��Ч
    #if defined(DYNAMICLIGHTMAP_ON)
        float2 dynamicLightmapUV : TEXCOORD7;
    #endif

    #if defined(_PARALLAX_MAP)
        float3 tangentViewDir : TEXCOORD8;              // ���߿ռ��µ����߷���ƬԪָ���������������
    #endif

    // �ж��Ƿ��м�����ɫ��������������
    #if defined(CUSTOM_GEOMETRY_INTERPOLATORS)
        CUSTOM_GEOMETRY_INTERPOLATORS                   // ͨ�����ȡ������ɫ���������Ĳ�ֵ������
    #endif
};

// ƬԪ�������ؽṹ��
struct FragmentOutPut{
    #if defined(DEFERRED_PASS)
        float4 gBuffer0 : SV_TARGET0;
        float4 gBuffer1 : SV_TARGET1;
        float4 gBuffer2 : SV_TARGET2;
        float4 gBuffer3 : SV_TARGET3;
		// �ж��Ƿ���������Ӱ����
		// �ж�ƽ̨�Ƿ�֧�ִ���4��gBuffer
		#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
			float4 gBuffer4 : SV_TARGET4;
		#endif
    #else
        float4 color : SV_Target;
    #endif
};

// �������Ի�����(������GPUInstance��ʱ�򣬷��ڻ����������Խ���һ��SetPassCalls���޸Ĳ�����Ⱦ״̬���Ϳ���һ�����������ж�������ԣ���instance idΪ�����Ž�������)
UNITY_INSTANCING_BUFFER_START(InstanceProperties)   
    // �൱��float4 _Color������ͬƽ̨��Щ��ͬ�������ú괦��
    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
    // ������ɫbuffer���飬�����ⲿ�����������Կ飬����ɫ����ӵ�л�����
    #define _Color_arr InstanceProperties
UNITY_INSTANCING_BUFFER_END(InstanceProperties)

sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;
float _Cutoff;                                  // ͸���Ȳü���ֵ

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;             // ���߰�͹������

sampler2D _MetallicMap;                         // ��������ͼ
float _Metallic;                                // ������
float _Smoothness;                              // �ֲڶ�

sampler2D _ParallaxMap;                         // �Ӳ���ͼ
float _ParallaxStrength;                        // �Ӳ�ǿ��

sampler2D _OcclusionMap;                        // ����Ӱ��ͼ
float _OcclusionStrength;                       // ����Ӱǿ��

sampler2D _EmissionMap;                         // �Է�����ͼ
float3 _Emission;                               // �Է�����ɫ


// �Խ�������ͼ���в�������ý����ȣ�rͨ����
float GetMetallic(Interpolators i){
    #if defined(_METALLIC_MAP)
        return tex2D(_MetallicMap, i.uv.xy).r * _Metallic;
    #else
        return _Metallic;
    #endif
}

// ��ôֲڶ�
float GetSmoothness(Interpolators i){
    float smoothness = 1;
    #if defined(_SMOOTHNESS_ALBEDO)
        smoothness = tex2D(_MainTex, i.uv.xy).a;
    #elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
        smoothness = tex2D(_MetallicMap, i.uv.xy).a;
    #endif
    return smoothness * _Smoothness;
}

// �������Ӱ
float GetOcclusion(Interpolators i){
    #if defined(_OCCLUSION_MAP)
        return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);  // ����Ӱǿ����0��ʱ�򷵻�1����ʾ��Ӱ���������գ���ǰǿ����1��ʱ���򷵻�����Ӱ��ͼ����ֵ
    #else
        return 1;
    #endif
}

// ����Է�����ɫ
float3 GetEmission(Interpolators i){
    // ǰ����Ⱦ�Ļ���pass���ӳ���Ⱦ��passʹ��
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        #if defined(_EMISSION_MAP)
            return tex2D(_EmissionMap, i.uv.xy) * _Emission;
        #else
            return _Emission;
        #endif
    #else
        return 0;
    #endif
}

// ���ϸ����ͼ����
float GetDetailMask(Interpolators i){
    #if defined(_DETAIL_MASK)
        return tex2D(_DetailMask, i.uv.xy).a;
    #else
        return 1;
    #endif
}

// ������������ɫ
float3 GetAlbedo(Interpolators i){
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).rgb;
    #if defined(_DETAIL_ALBEDO_MAP)
        float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * details, GetDetailMask(i));
    #endif
    return albedo;
}

// ���͸����
float GetAlpha(Interpolators i){
    float alpha = UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a;
    // ����ֲڶ���Դ�����������aͨ��
    #if !defined(_SMOOTHNESS_ALBEDO)
        alpha = UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a * tex2D(_MainTex, i.uv.xy).a;
    #endif
    return alpha;
}

// ��ȡ���߿ռ�ķ���
float3 GetTangentSpaceNormal(Interpolators i){
    float3 normal = float3(0, 0, 1);

    #if defined(_NORMAL_MAP)
        normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);                              // ��������ͼ������ƽ̨�Զ��Է�������ͼʹ����ȷ�Ľ��룬�����ŷ���
    #endif
    
    #if defined(_DETAIL_NORMAL_MAP)
        float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);                // ϸ�ڷ�����ͼ�� ����ƽ̨�Զ��Է�������ͼʹ����ȷ�Ľ��룬�����ŷ���
        detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));                                       // ���ϸ����ͼ����
        normal = BlendNormals(normal, detailNormal);                                                                // �ںϷ���
    #endif

    return normal;
}

// �����������Ӳ���ͼ
float GetParallaxHeight(float2 uv)
{
    return tex2D(_ParallaxMap, uv).g;
}

#endif