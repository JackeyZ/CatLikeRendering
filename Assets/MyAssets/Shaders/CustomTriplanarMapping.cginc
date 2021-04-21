// 三向着色器表面函数部分
// 包含着色器所需的所有表面属性(反射率，自发光，法线等等)
// 通过重写表面函数来改变原来默认着色器的功能
#if !defined(CUSTOM_TRIPLANARMAPPING_INLCUDE)
#define CUSTOM_TRIPLANARMAPPING_INLCUDE

// 表示网格没有默认的UV可用，需要自己算
#define NO_DEFAULT_UV

#include "CustomLightingInput.cginc"

sampler2D _MOHSMap;
sampler2D _TopMainTex, _TopMOHSMap, _TopNormalMap;
float _MapScale;
float _BlendOffset, _BlendExponent, _BlendHeightStrength;

struct TriplanarUV{
	float2 x, y, z;
};
TriplanarUV GetTriplanarUV(SurfaceParameters parameters){
	TriplanarUV triUV;
	float3 p = parameters.position * _MapScale;	// 片元世界坐标 * 缩放
	triUV.x = p.zy;								// 朝向是x方向上的片元，用世界坐标的zy作为uv
	triUV.y = p.xz;								// 朝向是y方向上的片元，用世界坐标的xz作为uv
	triUV.z = p.xy;								// 朝向是z方向上的片元，用世界坐标的xy作为uv
	
	// 避免u坐标镜像
	// x轴穿过的平面，片元的u坐标就是世界坐标z值，x轴负方向上的平面，摄像机面朝该平面，越往右边z轴越小u越小，正常应该是越往右u越大，不然采样贴图会左右反转，所以这里u坐标取个反。
	if(parameters.normal.x < 0){
		triUV.x.x = -triUV.x.x;
	}
	if(parameters.normal.y < 0){
		triUV.y.x = -triUV.y.x;
	}
	if(parameters.normal.z >= 0){
		triUV.z.x = -triUV.z.x;
	}

	// 错开0.5个单位，避免角落贴图重复
	triUV.x.y += 0.5;
	triUV.z.x += 0.5;

	return triUV;
}

// 根据世界空间的法线得到片元的x、y、z三个朝向的权重，返回的x分量越大表示越朝向x方向
float3 GetTriplanarWeights(SurfaceParameters parameters, float heightX, float heightY, float heightZ)
{
	float3 triW = abs(parameters.normal);
	triW = saturate(triW - _BlendOffset);		// 减去偏移值，三个权重减去一个同样的值的时候，原本较小的权重会变得更加不重要
	triW *= lerp(1, float3(heightX, heightY, heightZ), _BlendHeightStrength);	// 对应方向的高度越高，则权重越大
	triW = pow(triW, _BlendExponent);			// 对三个权重做一个指数计算，原本较小的权重会变得更加不重要，这个改变是非线性的
	return triW / (triW.x + triW.y + triW.z);	// 得到三个分量的占比
}

// 融合法线
float3 BlendTriplanarNormal(float3 mappedNormal, float3 surfaceNormal){
	float3 n;
	n.xy = mappedNormal.xy + surfaceNormal.xy;	// 法线的xy表示倾斜度，二者倾斜度应该叠加，所以这里相加，而垂直的法线（平的）不应该改变另一个法线。
	n.z = mappedNormal.z * surfaceNormal.z;		// z值进行普通的融合相乘
	return n;
}

// 表面函数
void MyTriPlanarSurfaceFunction(inout SurfaceData surface, SurfaceParameters parameters)
{
	// 得到三个朝向的反射率
	TriplanarUV triUV = GetTriplanarUV(parameters);
	float3 albedoX = tex2D(_MainTex, triUV.x).rgb;
	float3 albedoY = tex2D(_MainTex, triUV.y).rgb;
	float3 albedoZ = tex2D(_MainTex, triUV.z).rgb;
	
	// 采样金属、自阴影、平滑度
	float4 mohsX = tex2D(_MOHSMap, triUV.x);
	float4 mohsY = tex2D(_MOHSMap, triUV.y);
	float4 mohsZ = tex2D(_MOHSMap, triUV.z);
	
	// 采样切线空间下的法线
	float3 tangentNormalX = UnpackNormal(tex2D(_NormalMap, triUV.x));
	float4 rawNormalY = tex2D(_NormalMap, triUV.y);						// 暂时调用UnpackNormal，避免顶部的片元出现两次采样的情况
	float3 tangentNormalZ = UnpackNormal(tex2D(_NormalMap, triUV.z));

	// 判断图形上方是否需要采样特定的贴图
	#if defined(_SEPARATE_TOP_MAPS)
		// 如果片元朝上, 改成采样顶部贴图
		if(parameters.normal.y > 0){
			albedoY = tex2D(_TopMainTex, triUV.y).rgb;
			mohsY = tex2D(_TopMOHSMap, triUV.y);
			rawNormalY = tex2D(_TopNormalMap, triUV.y);
		}
	#endif
	float3 tangentNormalY = UnpackNormal(rawNormalY);

	// 转换预处理
	// GetTriplanarUV取uv的时候为了防止图像左右反转，x轴负方向穿过的平面进行采样时取反了u坐标，即世界坐标z值越小u越大
	// 设x轴正方向上采样到的法线是（1,1,1），x轴负方向上同样的uv坐标采样到的法线也会是（1,1,1），
	// 此时转换到世界空间，x轴负方向上的片元的法线的x分量将转换成世界空间的z值，z应该要是一个负数，但这里的x是正的，所以这里预先对x取反，后面得到的世界坐标z才会是一个负数
	// 原本z值也需要做同样的处理，但是因为后面BlendTriplanarNormal函数中，采样的法线和mesh的法线进行融合的时候是相乘，负负得正，抵消了，所以这里不进行处理
	if(parameters.normal.x < 0){
		tangentNormalX.x = -tangentNormalX.x;
	}
	if(parameters.normal.y < 0){
		tangentNormalY.x = -tangentNormalY.x;
	}
	if(parameters.normal.z < 0){
		tangentNormalZ.x = -tangentNormalZ.x;
	}

	// 先把片元mesh原本的世界空间法线转换到切线空间（坐标轴负方向上的点，转化后正负值会相反，但由于上面做了预处理会相互抵消）下融合，
	// 再把结果转换到世界空间，这样子是为了不让采样的法线与表面原始法线偏离太多
	// 转换成世界空间下的转换原理：世界空间x方向上，切线空间下的z就是世界空间下的x，切线空间yx就是世界空间的yz(右手螺旋)
	float3 worldNormalX = BlendTriplanarNormal(tangentNormalX, parameters.normal.zyx).zyx;		
	float3 worldNormalY = BlendTriplanarNormal(tangentNormalY, parameters.normal.xzy).xzy;
	float3 worldNormalZ = BlendTriplanarNormal(tangentNormalZ, parameters.normal);						// z轴方向上切线空间与世界空间的基底一致，不需要转换


	float3 triW = GetTriplanarWeights(parameters, mohsX.b, mohsY.b, mohsZ.b);							// 得到当前片元的朝向权重
	surface.albedo = albedoX * triW.x + albedoY * triW.y + albedoZ * triW.z;							// 根据权重计算反射率

	float4 mohs = mohsX * triW.x + mohsY * triW.y + mohsZ * triW.z;
	surface.metallic = mohs.r;																			// 金属度
	surface.occlusion = mohs.g;																			// 自阴影
	surface.smoothness = mohs.a;																		// 平滑度
	surface.normal = normalize(worldNormalX * triW.x + worldNormalY * triW.y + worldNormalZ * triW.z);	// 法线
}

// 定义获取表面数据的方法，提供给后续片元着色器调用
#define SURFACE_FUNCTION MyTriPlanarSurfaceFunction
#endif