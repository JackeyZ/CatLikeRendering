#if !defined(CUSTOM_SHADOWS_INCLUDE)
#define CUSTOM_SHADOWS_INCLUDE

#include "UnityCG.cginc"

// �������Ի�����(������GPUInstance��ʱ�򣬷��ڻ����������Խ���һ��SetPassCalls���޸Ĳ�����Ⱦ״̬���Ϳ���һ�����������ж�������ԣ���instance idΪ�����Ž�������)
UNITY_INSTANCING_BUFFER_START(InstanceProperties)   
    // �൱��float4 _Color������ͬƽ̨��Щ��ͬ�������ú괦��
    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
    // ������ɫbuffer���飬�����ⲿ�����������Կ飬����ɫ����ӵ�л�����������Ӱpass��ȡ����ʵ����͸����
    #define _Color_arr InstanceProperties
UNITY_INSTANCING_BUFFER_END(InstanceProperties)

sampler2D _MainTex;			// ������
float4 _MainTex_ST;			// ����������ƫ��
float _Cutoff;				// ͸���Ȳü���ֵ
sampler3D _DitherMaskLOD;	// unity�Դ��Ķ�������һ��ʮ����ģʽ


// ��ȾģʽΪ����͸�����������͸����
#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
	// �ж��Ƿ�ʹ�ð�͸����Ӱ
	#if defined(_SEMITRANSPARENT_SHADOWS)
		#define SHADOWS_SEMITRANSPARENT 1
	#else
		#define _RENDERING_CUTOUT
	#endif
#endif

// �����Ⱦģʽ��ȫ͸���ü����͸�������Ҵֲڶ���Դ�����������aͨ�������������Ӱ��Ҫ��������͸���Ƚ��в���
#if SHADOWS_SEMITRANSPARENT || defined(_RENDERING_CUTOUT)
	#if !defined(_SMOOTHNESS_ALBEDO)
		#define SHADOWS_NEED_UV 1
	#endif
#endif

struct VertexData{
    UNITY_VERTEX_INPUT_INSTANCE_ID                      // ʵ��ID , ��һ��uint����ͬƽ̨����᲻ͬ�����忴Դ�룬֧��GPUInstance 
	float4 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};

// ���㺯���õĽṹ��
struct InterpolatorsVertex{
    UNITY_VERTEX_INPUT_INSTANCE_ID              // ʵ��ID , ��һ��uint����ͬƽ̨����᲻ͬ�����忴Դ�룬֧��GPUInstance 
	float4 position : SV_POSITION;

	#if SHADOWS_NEED_UV
		float2 uv : TEXCOORD0;
	#endif

	// Ϊ�˽�����ԴͶӰ������,���multi_compile_shadowcaster�� Ӧ����ĳЩƽ̨��֧��ֱ���ö�����ɫ��������depth buffer��Ҫ�Լ���ƬԪ������������
	#if defined(SHADOWS_CUBE)
		float3 lightVec : TEXCOORD0;
	#endif
};

// ƬԪ�����õĽṹ��
struct Interpolators{
    UNITY_VERTEX_INPUT_INSTANCE_ID              // ʵ��ID , ��һ��uint����ͬƽ̨����᲻ͬ�����忴Դ�룬֧��GPUInstance 
	// �ж��Ƿ��ǰ�͸����Ӱ����LOD���뵭��
	#if SHADOWS_SEMITRANSPARENT || defined(LOD_FADE_CROSSFADE)
		UNITY_VPOS_TYPE vpos : VPOS;			// VPOS:��Ļ�������꣨���Ƕ�����ɫ������ģ���GPU�����   UNITY_VPOS_TYPE���൱��float4, DX9��float2
	#else
		float4 positions : SV_POSITION;			// �ü��ռ����꣬��ʱû�õ���������Ϊ�˷�ֹ�ṹ��Ϊ�գ����Ա�������
	#endif

	#if SHADOWS_NEED_UV
		float2 uv : TEXCOORD0;
	#endif

	#if defined(SHADOWS_CUBE)
		float3 lightVec : TEXCOORD1;
	#endif
};

// ���͸����
float GetAlpha(Interpolators i){
    float alpha =  UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a;
    // ����ֲڶ���Դ�����������aͨ��
    #if SHADOWS_NEED_UV
        alpha =  UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a * tex2D(_MainTex, i.uv.xy).a;
    #endif
    return alpha;
};

InterpolatorsVertex MyShadowVertexProgram(VertexData v){
	InterpolatorsVertex i;
	UNITY_SETUP_INSTANCE_ID(v);																// �������GPUInstance,�Ӷ����������instance id�޸�unity_ObjectToWorld��������ֵ��ʹ�������UnityObjectToClipPosת������ȷ���������꣬����ͬλ�õĶ��������Ӱ��ͬһ������Ⱦ��ʱ�򣬴�ʱ���Ǵ�������ģ�Ϳռ�������һ���ģ����ı�unity_ObjectToWorld����Ļ������õ���������������ͬһ��λ�ã����������ͬһ���ط�����
	UNITY_TRANSFER_INSTANCE_ID(v, i);														// ��instance id��v�ṹ�帳ֵ��i�ṹ��

	#if defined(SHADOWS_CUBE)
		i.position = UnityObjectToClipPos(v.position);
		i.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;	// _LightPositionRange��xyz�ǹ�Դ���� w��1/Range
	#else
		i.position = UnityClipSpaceShadowCasterPos(v.position, v.normal);					// ת�����ü����꣬����ִ�ж��㷨��ƫ��
		i.position = UnityApplyLinearShadowBias(i.position);								// ƫ�Ʋü������zֵ�����ض���ü������
	#endif

	#if SHADOWS_NEED_UV 
		i.uv = TRANSFORM_TEX(v.uv, _MainTex);
	#endif

	return i;
}

float4 MyShadowFragmentProgram(Interpolators i): SV_TARGET {
	// �ж��ǲ�������LOD���뵭��
	#if defined(LOD_FADE_CROSSFADE)
		UnityApplyDitherCrossFade(i.vpos);
	#endif

	float alpha = GetAlpha(i);
	// �����Ⱦģʽ��ȫ͸��cutout����ü���cutout����ƬԪ����Ӱ
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _Cutoff);
	#endif

	// �����Ⱦģʽ�ǰ�͸��
	#if SHADOWS_SEMITRANSPARENT
		float dither = tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9375)).a; // * 0.25�����Ŷ�����ͼ���ڶ��������ĵ�����������Χ��0~0.9375����Ӧ���������16��ģʽ��0/16, 1/16, 2/16 ... 15/16��
		clip(dither - 0.01);															  // �ѽӽ�ȫ͸����ƬԪ����
	#endif


	// �Լ��������
	#if defined(SHADOWS_CUBE)
		float depth = length(i.lightVec) + unity_LightShadowBias.x;
		depth *= _LightPositionRange.w;														// _LightPositionRange.w��1/Range�� Range�ǹ�Դ�ķ�Χ
		return UnityEncodeCubeShadowDepth(depth);
	#else
		return 0;
	#endif
}


// ���ֱ�ӵ���unity�Դ��ĺ꣬���������д
//struct Interpolators{
//	V2F_SHADOW_CASTER;
//};

//Interpolators MyShadowVertexProgram(appdata_base v){
//	Interpolators i;
//	TRANSFER_SHADOW_CASTER_NORMALOFFSET(i);
//	return i;
//}

//float4 MyShadowFragmentProgram(Interpolators i): SV_TARGET {
//	SHADOW_CASTER_FRAGMENT(i);
//}

#endif