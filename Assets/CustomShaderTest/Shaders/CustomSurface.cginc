// 包含所有着色器所需的表面属性(反射率，自发光，法线等等)
#if !defined(CUSTOM_SURFACE_INCLUDE)
#define CUSTOM_SURFACE_INCLUDE

// 用于记录表面信息，提供给片元着色器计算
struct SurfaceData{
	float3 albedo;		// 反射率
	float3 emission;	// 自发光
	float3 normal;		// 法线
	float alpha;		// 透明度
	float metallic;		// 金属度
	float occlusion;	// 自阴影
	float smoothness;	// 平滑度
};

// 用于记录顶点着色器传递到片元着色器的部分信息，然后传递给表面信息函数
struct SurfaceParameters {
	float3 normal, position;
	float4 uv;
};

#endif