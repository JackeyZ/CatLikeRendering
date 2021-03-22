#if !defined(CUSTOM_SHADOWS_INCLUDE)
#define CUSTOM_SHADOWS_INCLUDE

#include "UnityCG.cginc"

// 如果使用视差贴图，且启用顶点偏移
#if defined(_PARALLAX_MAP) && defined(VERTEX_DISPLACEMENT_INSTEAD_OF_PARALLAX)
    // 取消使用uv的视差偏移
    #undef _PARALLAX_MAP               
    // 启用顶点偏移
    #define VERTEX_DISPLACEMENT 1       
    // 给视差贴图的变量弄个新别名，在细分着色器里用
    #define _DisplacementMap _ParallaxMap
    // 给视差强度弄个新别名，在细分着色器里用
    #define _DisplacementStrength _ParallaxStrength
	// 需要采样贴图，所以这里启用需要uv的宏
	#if !defined(SHADOWS_NEED_UV)
		#define SHADOWS_NEED_UV 1
	#endif
#endif

// 创建属性缓冲区(在启用GPUInstance的时候，放在缓冲区的属性仅需一次SetPassCalls（修改材质渲染状态）就可以一次性设置所有对象的属性，以instance id为索引放进缓冲里)
UNITY_INSTANCING_BUFFER_START(InstanceProperties)   
    // 相当于float4 _Color，但不同平台有些许不同，这里用宏处理
    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
    // 定义颜色buffer数组，储存外部传进来的属性块，令颜色属性拥有缓冲区，本阴影pass读取的其实就是透明度
    #define _Color_arr InstanceProperties
UNITY_INSTANCING_BUFFER_END(InstanceProperties)


sampler2D _MainTex;			// 主纹理
float4 _MainTex_ST;			// 主纹理缩放偏移
float _Cutoff;				// 透明度裁剪阈值
sampler3D _DitherMaskLOD;	// unity自带的抖动纹理，一共十六个模式
sampler2D _ParallaxMap;
float _ParallaxStrength;

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
    UNITY_VERTEX_INPUT_INSTANCE_ID                      // 实例ID , 是一个uint，不同平台语义会不同，具体看源码，支持GPUInstance 
	float4 vertex : POSITION;							// 与CustomLighting里的变量名保持一致，因为都会在曲面细分（CustomTessellation）里面用到
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};

// 顶点函数用的结构体
struct InterpolatorsVertex{
    UNITY_VERTEX_INPUT_INSTANCE_ID              // 实例ID , 是一个uint，不同平台语义会不同，具体看源码，支持GPUInstance 
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
    UNITY_VERTEX_INPUT_INSTANCE_ID              // 实例ID , 是一个uint，不同平台语义会不同，具体看源码，支持GPUInstance 
	// 判断是否是半透明阴影或者LOD淡入淡出
	#if SHADOWS_SEMITRANSPARENT || defined(LOD_FADE_CROSSFADE)
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
    float alpha =  UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a;
    // 如果粗糙度来源不是主纹理的a通道
    #if SHADOWS_NEED_UV
        alpha =  UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a * tex2D(_MainTex, i.uv.xy).a;
    #endif
    return alpha;
};

// 定义一个别名，让CustomTessellation调用
#define MyVertexProgram MyShadowVertexProgram
 
InterpolatorsVertex MyShadowVertexProgram(VertexData v){
	InterpolatorsVertex i;
	UNITY_SETUP_INSTANCE_ID(v);																// 用于配合GPUInstance,从而根据自身的instance id修改unity_ObjectToWorld这个矩阵的值，使得下面的UnityObjectToClipPos转换出正确的世界坐标，否则不同位置的多个对象阴影在同一批次渲染的时候，此时他们传进来的模型空间坐标是一样的，不改变unity_ObjectToWorld矩阵的话，最后得到的世界坐标是在同一个位置（多个对象挤在同一个地方）。
	UNITY_TRANSFER_INSTANCE_ID(v, i);														// 把instance id从v结构体赋值到i结构体

	#if SHADOWS_NEED_UV 
		i.uv = TRANSFORM_TEX(v.uv, _MainTex);
	#endif

	// 检查是否需要根据视差贴图偏移顶点
	#if VERTEX_DISPLACEMENT
		float displacement = tex2Dlod(_DisplacementMap, float4(i.uv.xy, 0, 0)).g;
		displacement = (displacement - 0.5) * _DisplacementStrength;						// 0~1转换成-0.5到0.5，之后乘以偏移强度
		v.normal = normalize(v.normal);
		v.vertex.xyz += v.normal * displacement;
	#endif

	#if defined(SHADOWS_CUBE)
		i.position = UnityObjectToClipPos(v.vertex);
		i.lightVec = mul(unity_ObjectToWorld, v.vertex).xyz - _LightPositionRange.xyz;		// _LightPositionRange的xyz是光源方向， w是1/Range
	#else
		i.position = UnityClipSpaceShadowCasterPos(v.vertex, v.normal);						// 转换到裁剪坐标，并且执行顶点法向偏差
		i.position = UnityApplyLinearShadowBias(i.position);								// 偏移裁剪坐标的z值并返回顶点裁剪坐标点
	#endif
	return i;
}

float4 MyShadowFragmentProgram(Interpolators i): SV_TARGET {
	// 判断是不是启用LOD淡入淡出
	#if defined(LOD_FADE_CROSSFADE)
		UnityApplyDitherCrossFade(i.vpos);
	#endif

	float alpha = GetAlpha(i);
	// 如果渲染模式是全透明cutout，则裁剪掉cutout掉的片元的阴影
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _Cutoff);
	#endif

	// 如果渲染模式是半透明
	#if SHADOWS_SEMITRANSPARENT
		float dither = tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9375)).a; // * 0.25来缩放抖动贴图，第二个参数的第三个分量范围是0~0.9375，对应抖动纹理的16个模式（0/16, 1/16, 2/16 ... 15/16）
		clip(dither - 0.01);															  // 把接近全透明的片元丢弃
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