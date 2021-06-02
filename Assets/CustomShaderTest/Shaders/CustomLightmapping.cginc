// ��Mate��Pass���õ�������֧�־�̬������ͼ�Ͷ�̬������ͼ
#if !defined(CUSTOM_LIGHTMAPPING_INLCUDE)
#define CUSTOM_LIGHTMAPPING_INLCUDE

// �����������ű�
#include "CustomLightingInput.cginc"        
#include "UnityMetaPass.cginc"           

// �����ȡ�����ʵķ���
#if !defined(ALBEDO_FUNCTION)
    #define ALBEDO_FUNCTION GetAlbedo
#endif

// ������ɫ��
// meta pass��VertexData����������
// vertex    ����Ĺ�����ͼ����ӳ������
// uv        ģ�Ͷ����ϵ�uv
// uv1       �����϶�Ӧ��̬������ͼ��uv��LIGHTMAP_ON�ؼ������õ�ʱ����Ч��
// uv2       �����϶�Ӧ��̬������ͼ��uv (��ѡLighting -> Realtime Lighting -> Realtime Global Illumination��Ч)
Interpolators MyLightmappingVertexProgram(VertexData v) 
{
    Interpolators i;
    //v.vertex.xy = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;    // �Թ�����ͼuv�������ź�ƫ��
    //v.vertex.z = v.vertex.z > 0 ? 0.0001 : 0;
    //i.pos = UnityObjectToClipPos(v.vertex);                             // uvת�����ü��ռ�

    // ���ݶ���Ĺ�����ͼ����ӳ�����꣬��ö�����ģ�Ϳռ��е�x��yֵ��Ȼ��任���ü��ռ��в�����
    i.pos = UnityMetaVertexPosition(v.vertex, v.uv1, v.uv2, unity_LightmapST, unity_DynamicLightmapST);

    // ����Ҫ��ʱ��ż�������ռ䷨��
    #if defined(META_PASS_NEEDS_NORMALS)
        i.normal = UnityObjectToWorldNormal(v.normal);
    #else
        i.normal = float3(0, 1, 0);
    #endif
    
    // ����Ҫ��ʱ��ż�����������
    #if defined(META_PASS_NEEDS_POSITION)
        i.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
    #else
        i.worldPos.xyz = 0;
    #endif

    // ӵ����ЧĬ��uv��ʱ��Ű�uv����ȥ
    #if !defined(NO_DEFAULT_UV)
        // ��uv�������ź�ƫ�ƣ�����ƬԪ��������ͼ����
        i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
        i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    #endif

    return i;
}

half4 MyLightmappingFragmentProgram(Interpolators i) : SV_target
{
    SurfaceData surface;
    surface.normal = normalize(i.normal);       // ����ռ䷨��
    surface.albedo = 1;                     
    surface.alpha = 1;
    surface.emission = 0;
    surface.metallic = 0;
    surface.occlusion = 1;
    surface.smoothness = 0.5;
    // �ж��Ƿ����˱��溯��
    #if defined(SURFACE_FUNCTION)
        SurfaceParameters sp;
        sp.normal = i.normal;
        sp.position = i.worldPos.xyz;
        sp.uv = UV_FUNCTION(i);
        SURFACE_FUNCTION(surface, sp);
    #else
        // ����̬������ͼ��̬������ͼ�ļ�ӹ���Ϣ�ֻ��Ҫ�ṩ���ĸ�����
        surface.albedo = ALBEDO_FUNCTION(i);
        surface.emission = GetEmission(i);
        surface.metallic = GetMetallic(i);
        surface.smoothness = GetSmoothness(i);
    #endif

    UnityMetaInput surfaceData;
    surfaceData.Emission = surface.emission;
    float oneMinusReflectivity;
    surfaceData.Albedo = DiffuseAndSpecularFromMetallic(surface.albedo, surface.metallic, surfaceData.SpecularColor, oneMinusReflectivity);     // �������������õ�������͸߹ⷴ����ɫ
    
    // �ǽ���Ӧ�ò��������ӹ⣬Խ�ֲ���ԽӦ�ðѸ߹ⷴ������ȵ��ӵ���������
    float roughness = SmoothnessToRoughness(surface.smoothness) * 0.5;                    // ƽ����ת���ɴֲڶȣ�������ת��������ʵ
    surfaceData.Albedo += surfaceData.SpecularColor * roughness;                        // Խ�ֲڣ�Խ�Ѹ߹ⷴ������ȵ��ӵ���������

    return UnityMetaFragment(surfaceData);                                              // ����������ɫ���������ֻ����������Է������õ�
}
#endif