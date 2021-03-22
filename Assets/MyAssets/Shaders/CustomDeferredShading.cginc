#if !defined(CUSTOM_DEFERRED_SHADING)
#define CUSTOM_DEFERRED_SHADING

//#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;
sampler2D _CameraGBufferTexture4;	// ��Ӱ����

float4 _LightColor, _LightDir;      // ֱ�ӹ���ɫ���䷽��
float4 _LightPos;                   // �Ƿ�������һ����Դλ��, rgb�����꣬w�ǹ��վ���
float _LightAsQuad;                 // ��ǰ�ڴ�������ı��ε�ʱ��Ҳ����ֱ��⣬ֵΪ1������ֵΪ0

#if defined(POINT_COOKIE)
    samplerCUBE _LightTexture0;     // ���Դ��cookie����
#else
    sampler2D _LightTexture0;       // ��Դ��cookie����
#endif
sampler2D _LightTextureB0;          // ��Դ��˥��������ֱ�����У�
float4x4 unity_WorldToLight;        // ����ռ䵽��Դ�ռ��ת������

// �ж��Ƿ���������Ļ�ռ���Ӱ
#if defined(SHADOWS_SCREEN)
    sampler2D _ShadowMapTexture;	// ������Ļ�ռ���Ӱ��ͼ
#endif

struct VertexData
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
};

struct Interpolators
{
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 ray : TEXCOORD1;
};

// ��ȡ��Ӱ����
float GetShadowMaskAttenuation(float2 uv)
{
	float attenuation = 1;
	// �ж��Ƿ���������Ӱ������ͼ
	#if defined(SHADOWS_SHADOWMASK)
		float4 mask = tex2D(_CameraGBufferTexture4, uv);					// ��gBuffer�������Ӱ���ֽ��в���
        // �ĸ��ƹ��Ӧmask���ĸ�ͨ��
		// unity_OcclusionMaskSelector���ڱ�����ǰ���ڱ���Ⱦ���ǵڼ����ƹ⡣
		// �������ǰ��Ⱦ�ĵƹ��ǵ�һ���ƹ⣬��unity_OcclusionMaskSelector����ֵΪ(1, 0, 0, 0)
        // ��˺�ѡ����뵱ǰ�ƹ��Ӧ��ͨ��ֵ
		attenuation = saturate(dot(mask, unity_OcclusionMaskSelector));		
	#endif
	return attenuation;
}

// ֱ�ӹ�(viewZ�Ǹ������������ӿڿռ��µ�zֵ���ӿڿռ��µ�zֵ�Ǹ���)
UnityLight CreateLight(float2 uv, float3 worldPos, float viewZ){
    UnityLight light;              // ֱ�ӹ�
    float attenuation = 1;
    float shadowAttenuation = 1;
    bool shadowed = false;

    // ����Ƿ����
    #if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
        light.dir = -_LightDir;        // ��Դ��ƬԪ������ת����ƬԪ����Դ������
        // �Ƿ���ֱ�������
        #if defined(DIRECTIONAL_COOKIE)
            float2 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xy;
            attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie, 0, -8)).w;            // -8��mipmap����ƫ��,���ⲻͬƬԪ��ȡ��ͬmipmap������������ν�������
        #endif

        // �ж��Ƿ���������Ļ�ռ���Ӱ
        #if defined(SHADOWS_SCREEN)
            shadowed = true;
            shadowAttenuation = tex2D(_ShadowMapTexture, uv).r;                             // ����Ļ�ռ���Ӱ��ͼ�����������Ӱ��1��ʾû����Ӱ
        #endif
    #else
        float3 lightVec = _LightPos.xyz - worldPos;
        light.dir = normalize(lightVec);

        // ����˥��
        attenuation *= tex2D(_LightTextureB0, (dot(lightVec, lightVec) * _LightPos.w).rr).UNITY_ATTEN_CHANNEL;       // �ã������ƽ��*���շ�Χ����������˥���� ��ͬƽ̨˥�������ڲ�ͬͨ����UNITY_ATTEN_CHANNEL��

        // �۹��cookie
        #if defined(SPOT)
            float4 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1));
            // ��Ϊ�Ǿ۹�ƣ�ӵ��͸�ӱ任������������͸�ӳ������õ�������uv
            uvCookie.xy /= uvCookie.w;      
            attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie.xy, 0, -8)).w;
            attenuation *= uvCookie.w < 0;  // �۹�ƺ󷽲�������׶����Ϊ���������w = -z����zΪ����ʱ���ھ۹�Ʊ��棬����wΪ����ʱ���ھ۹�Ƶı��棩
            
            // �жϾ۹���Ƿ�Ͷ����Ӱ
            #if defined(SHADOWS_DEPTH)
                shadowed = true;
                shadowAttenuation = UnitySampleShadowmap(mul(unity_WorldToShadow[0], float4(worldPos, 1)));     // ����Ӱ��ͼ���в�������Ҫ����һ����Ӱ�ռ����꣬unity_WorldToShadow[0]���԰����������ռ�ת������Ӱ�ռ�
            #endif
        #else
            // ���Դcookie
            #if defined(POINT_COOKIE)
                float3 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xyz;     // ������ռ�����ת������Դ�ռ�
                attenuation *= texCUBEbias(_LightTexture0, float4(uvCookie, -8)).w;     // �Ե��Դcookie���в���
            #endif
            // ������Ӱ��ͼ�����Դ��
            #if defined(SHADOWS_CUBE)
                shadowed = true;
                shadowAttenuation = UnitySampleShadowmap(-lightVec);
            #endif
        #endif
    #endif

	#if defined(SHADOWS_SHADOWMASK)
		shadowed = true;
	#endif

    if(shadowed){
        float shadowFadeDistance = UnityComputeShadowFadeDistance(worldPos, viewZ);     // �õ�ƬԪ����Ӱ�������ģ�˥�����ģ��ľ���
        float shadowFade = UnityComputeShadowFade(shadowFadeDistance);                  // ����ƬԪ��˥�����ĵľ��������Ӱ˥��ֵ,0~1��0��ʾ��˥����1��ʾȫ˥��(��û����Ӱ)
        //shadowAttenuation = saturate(shadowAttenuation + shadowFade);                 // ����Ӱ˥��Ӧ�õ���Ӱֵ��
		shadowAttenuation = UnityMixRealtimeAndBakedShadows(shadowAttenuation, GetShadowMaskAttenuation(uv), shadowFade);  // ����Ӱ˥������Ӱ����Ӧ�õ���Ӱֵ��

        // UNITY_FAST_COHERENT_DYNAMIC_BRANCHING Ŀ��ƽ̨�Ƿ�֧�ֶ������֧�Ż���֧�ֵ�ƽ̨��ʹ�����µĲ���
        // �����֧�����󲿷�������ƬԪ����������һ����֧�Ĵ��루������Ӱ����ı�Ե����������ƬԪ���䵽��Ӱ���ڲ����ⲿ�����󲿷�������ģ�
        // SHADOWS_SOFT �Ƿ�������Ӱ������Ӱ��β����Ƚϰ�������������һ����֧���Ż���
        #if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT)
			// δ������Ӱ���ֲŽ���ȫ˥���Ż�����Ϊ�����������Ӱ���֣�ƬԪ�ڳ�����Ӱ����֮����ȡ��Ӱ���ֵ�ֵ�������ڳ���������Ӱ˥�������
			#if !defined(SHADOWS_SHADOWMASK)
				// ����һ����̬��֧����������Ū��һ���ٷ�֧�����·�֧���ߵ��߼�������
				UNITY_BRANCH        
				// �ж�˥��ֵ�Ƿ���ȫ˥��������ǵĻ�����ƬԪ������Ӱ˥������̫Զ�ˣ�ֱ�Ӱ���Ӱ������ֵ���1�����������Ĵ���Ͳ���Ҫ����Ӱ��ͼ���в����ˣ��Ż�����
				if(shadowFade > 0.99){
					shadowAttenuation = 1; 
				}
			#endif
        #endif
    }

    light.color = _LightColor.rgb * (attenuation * shadowAttenuation);
    return light;
}

Interpolators VertexProgram(VertexData v){
    Interpolators i;
    i.pos = UnityObjectToClipPos(v.vertex);
    i.uv = ComputeScreenPos(i.pos);                 // �ü��ռ��������ת��Ϊ��Ļ�ռ��������[-w, w] => [0, w]

    // ֱ��������������ȫ���ı��ε�ʱ�� ���ߴ��������������λ�õ����������ĸ�����ķ�������, _LightAsQuad��ֵΪ1
    // �������ֱ���������3D��״����Ҫ�Լ����㣬_LightAsQuad��ֵΪ0
    // * float3(-1, -1, 1)��Ϊ�����ƬԪ��ɫ������ļ���rayToFarPlane�Ĳ�������Ϊ�ӿڿռ�������������ϵ�������ǰ������zֵ���Ǹ�������_ProjectionParams.z������
    // ���磺���ӿڿռ������꣨-1�� -1�� -1������i.ray * _ProjectionParams.z / i.ray.z֮��x��y���������������ˣ�����������ǰ��תһ��x��y����* float3��1, 1, -1��Ҳ�ܴﵽ����x��y��ת��Ŀ��
    i.ray = lerp(UnityObjectToViewPos(v.vertex) * float3(-1, -1, 1), v.normal, _LightAsQuad);

    return i;
}

float4 FragmentProgram(Interpolators i) : SV_Target
{ 
    float2 uv = i.uv.xy / i.uv.w;                                   // ͨ����γ����õ�������uv
    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
    depth = Linear01Depth(depth);
    // �������Զ�������ĸ�����ķ�������
    float3 rayToFarPlane = i.ray * _ProjectionParams.z / i.ray.z;  // i.ray������������������ƬԪ�ķ���������������ת��Ϊ�������Զ�������ƬԪ�ķ���������_ProjectionParams.z���������Զ������ľ��루һ����ֵ��
                                                                   // ����i,ray.z��һ�����������Դ�ʱ�õ���rayToFarPlane��zֵ����ֵ

    // �ӿڿռ��µ�ƬԪ����,��zֵ����������������൱����������ϵ��
    float3 viewPos = rayToFarPlane * depth; 
    // ����ռ��µ�ƬԪ����
    float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz; // unity_CameraToWorld�����Ͽ��Ǵ��ӿڿռ�ת��������ռ䣬��������ӿڿռ�����������ϵ���������ǰ����zֵ������
    // ����ռ��µ��������ƬԪ�ķ������������߷���
    float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);
    
    // ��GBuffer������ȡ�������ݣ����ݶ�ӦCuistomLighting����FragmentOutPut�ṹ����ӳ���Ⱦ���֣�
    float3 albedo = tex2D(_CameraGBufferTexture0, uv).rgb;
    float3 specularTint = tex2D(_CameraGBufferTexture1, uv).rgb;
    float3 smoothness = tex2D(_CameraGBufferTexture1, uv).a;
    float3 normal = tex2D(_CameraGBufferTexture2, uv).rgb * 2 - 1;
    // 1-�߹ⷴ�䷴����
    float oneMinusReflectivity = 1 - SpecularStrength(specularTint);        // SpecularStrength�������ڵõ�������ɫ������rgb���е����ֵ

    UnityLight light = CreateLight(uv, worldPos, viewPos.z);                // ֱ�ӹ�

    UnityIndirect indirectLight;                                            // ��ӹ�
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    float4 color = UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity, smoothness, normal, viewDir, light, indirectLight);

    // ���������Ƿ��õ�LDR
    #if !defined(UNITY_HDR_ON)
        color = exp2(-color);   // �Թ�����ɫ���б��룬LDR�»��Ӧ��DefferredShading.shader��ĵڶ���pass����log2���н���
    #endif

    return color;
}

#endif