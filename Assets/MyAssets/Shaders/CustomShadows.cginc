#if !defined(CUSTOM_SHADOWS_INCLUDE)
#define CUSTOM_SHADOWS_INCLUDE

#include "UnityCG.cginc"

float4 _Color;				// 主纹理颜色
sampler2D _MainTex;			// 主纹理
float4 _MainTex_ST;			// 主纹理缩放偏移
float _Cutoff;				// 透明度裁剪阈值
sampler3D _DitherMaskLOD;	// unity自带的抖动纹理，一共十六个模式


// 渲染模式为：半透明或漫反射半透明的
#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
	// 判断是否使用半透明阴影
	#if defined(_SEMITRANSPARENT_SHADOWS)
		#define SHADOWS_SEMITRANSPARENT 1
	#else
		#define _RENDERING_CUTOUT
	#endif
#endif

// 如果渲染模式是全透明裁剪或半透明，并且粗糙度来源不是主纹理的a通道，则下面的阴影需要对主纹理透明度进行采样
#if SHADOWS_SEMITRANSPARENT || defined(_RENDERING_CUTOUT)
	#if !defined(_SMOOTHNESS_ALBEDO)
		#define SHADOWS_NEED_UV 1
	#endif
#endif

struct VertexData{
	float4 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};

// 顶点函数用的结构体
struct InterpolatorsVertex{
	float4 position : SV_POSITION;

	#if SHADOWS_NEED_UV
		float2 uv : TEXCOORD0;
	#endif

	// 为了解决点光源投影的问题,配合multi_compile_shadowcaster， 应该是某些平台不支持直接拿顶点着色器产生的depth buffer，要自己在片元函数里计算深度
	#if defined(SHADOWS_CUBE)
		float3 lightVec : TEXCOORD0;
	#endif
};

// 片元函数用的结构体
struct Interpolators{
	#if SHADOWS_SEMITRANSPARENT
		UNITY_VPOS_TYPE vpos : VPOS;			// VPOS:屏幕像素坐标（不是顶点着色器输出的，由GPU输出）   UNITY_VPOS_TYPE：相当于float4, DX9是float2
	#else
		float4 positions : SV_POSITION;			// 裁剪空间坐标，暂时没用到，在这里为了防止结构体为空，所以保留下来
	#endif

	#if SHADOWS_NEED_UV
		float2 uv : TEXCOORD0;
	#endif

	#if defined(SHADOWS_CUBE)
		float3 lightVec : TEXCOORD1;
	#endif
};

// 获得透明度
float GetAlpha(Interpolators i){
    float alpha = _Color.a;
    // 如果粗糙度来源不是主纹理的a通道
    #if SHADOWS_NEED_UV
        alpha = _Color.a * tex2D(_MainTex, i.uv.xy).a;
    #endif
    return alpha;
};

InterpolatorsVertex MyShadowVertexProgram(VertexData v){
	InterpolatorsVertex i;
	#if defined(SHADOWS_CUBE)
		i.position = UnityObjectToClipPos(v.position);
		i.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;	// _LightPositionRange的xyz是光源方向， w是1/Range
	#else
		i.position = UnityClipSpaceShadowCasterPos(v.position, v.normal);					// 转换到裁剪坐标，并且执行顶点法向偏差
		i.position = UnityApplyLinearShadowBias(i.position);								// 偏移裁剪坐标的z值并返回顶点裁剪坐标点
	#endif

	#if SHADOWS_NEED_UV 
		i.uv = TRANSFORM_TEX(v.uv, _MainTex);
	#endif

	return i;
}

float4 MyShadowFragmentProgram(Interpolators i): SV_TARGET {
	float alpha = GetAlpha(i);
	// 如果渲染模式是全透明cutout，则裁剪掉cutout掉的片元的阴影
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _Cutoff);
	#endif

	// 如果渲染模式是半透明
	#if SHADOWS_SEMITRANSPARENT
		float dither = tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9375)).a; // 第二个参数的第三个分量范围是0~1，对应抖动纹理的16个模式（0/16, 1/16, 2/16 ... 16/16）
		clip(dither - 0.01);
	#endif


	// 自己计算深度
	#if defined(SHADOWS_CUBE)
		float depth = length(i.lightVec) + unity_LightShadowBias.x;
		depth *= _LightPositionRange.w;														// _LightPositionRange.w是1/Range， Range是光源的范围
		return UnityEncodeCubeShadowDepth(depth);
	#else
		return 0;
	#endif
}


// 如果直接调用unity自带的宏，则可以这样写
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