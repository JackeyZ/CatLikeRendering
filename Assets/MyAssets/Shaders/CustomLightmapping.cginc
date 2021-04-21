#if !defined(CUSTOM_LIGHTMAPPING_INLCUDE)
#define CUSTOM_LIGHTMAPPING_INLCUDE

#include "UnityPBSLighting.cginc"        
#include "UnityMetaPass.cginc"           

// ���㺯������
struct appdata
{
    float4 vertex : POSITION;                           // ����Ĺ�����ͼ����ӳ������
    float2 uv : TEXCOORD0;                              // ģ�Ͷ����ϵ�uv
    float2 uv1 : TEXCOORD1;                             // �����϶�Ӧ��̬������ͼ��uv��LIGHTMAP_ON�ؼ������õ�ʱ����Ч��
    float2 uv2 : TEXCOORD2;                             // �����϶�Ӧ��̬������ͼ��uv (��ѡLighting -> Realtime Lighting -> Realtime Global Illumination��Ч)
};

// ƬԪ��������
struct Interpolators
{
    float4 pos : SV_POSITION;                           // �ü����꣬д������Ϊpos���TRANSFER_SHADOWʹ��
    float4 uv : TEXCOORD0;
};

float4 _Color;
sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;

sampler2D _MetallicMap;                         // ��������ͼ
float _Metallic;                                // ������
float _Smoothness;                              // �ֲڶ�

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
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
    #if defined(_DETAIL_ALBEDO_MAP)
        float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * details, GetDetailMask(i));
    #endif
    return albedo;
}

// ����Է�����ɫ
float3 GetEmission(Interpolators i){
    #if defined(_EMISSION_MAP)
        return tex2D(_EmissionMap, i.uv.xy) * _Emission;
    #else
        return _Emission;
    #endif
}

Interpolators MyLightmappingVertexProgram(appdata v)
{
    Interpolators i;
    //v.vertex.xy = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;    // �Թ�����ͼuv�������ź�ƫ��
    //v.vertex.z = v.vertex.z > 0 ? 0.0001 : 0;
    //i.pos = UnityObjectToClipPos(v.vertex);                             // uvת�����ü��ռ�

    // ���ݶ���Ĺ�����ͼ����ӳ�����꣬��ö�����ģ�Ϳռ��е�x��yֵ��Ȼ��任���ü��ռ��в�����
    i.pos = UnityMetaVertexPosition(v.vertex, v.uv1, v.uv2, unity_LightmapST, unity_DynamicLightmapST);

    // ��uv�������ź�ƫ�ƣ�����ƬԪ��������ͼ����
    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);

    return i;
}

half4 MyLightmappingFragmentProgram(Interpolators i) : SV_target
{
    UnityMetaInput surfaceData;
    surfaceData.Emission = GetEmission(i);
    float oneMinusReflectivity;
    surfaceData.Albedo = DiffuseAndSpecularFromMetallic(GetAlbedo(i), GetMetallic(i), surfaceData.SpecularColor, oneMinusReflectivity);     // �������������õ�������͸߹ⷴ����ɫ
    
    // �ǽ���Ӧ�ò��������ӹ⣬Խ�ֲ���ԽӦ�ðѸ߹ⷴ������ȵ��ӵ���������
    float roughness = SmoothnessToRoughness(GetSmoothness(i)) * 0.5;            // ƽ����ת���ɴֲڶȣ�������ת��������ʵ
    surfaceData.Albedo += surfaceData.SpecularColor * roughness;                // Խ�ֲڣ�Խ�Ѹ߹ⷴ������ȵ��ӵ���������

    return UnityMetaFragment(surfaceData);                                      // ����������ɫ���������ֻ����������Է������õ�
}
#endif