// 平坦和线框着色（几何着色器）
#if !defined(FLAT_WIREFRAME_INCLUDED)
#define FLAT_WIREFRAME_INCLUDED

// 用来储存片元在三角面重心坐标系下的坐标，由于重心空间下坐标加起来总是1，所以这里只需要两个分量（float2）就可以了
// 重心坐标系：重心c的坐标是(1/3,1/3,1/3), 片元越靠近顶点1，则x越靠近1, 片元越靠近顶点2，则y越靠近1
#define CUSTOM_GEOMETRY_INTERPOLATORS float2 barycentricCoordinates : TEXCOORD9;

#include "CustomLightingInput.cginc"

float3 _WireframeColor;												// 线框颜色
float _WireframeSmoothing;											// 线框过渡区域宽度（像素）
float _WireframeThickness;											// 线框宽度（像素）

// 重写custom lighting input.cginc里的方法
float3 GetAlbedoWithWireframe(Interpolators i)
{
	float3 albedo = GetAlbedo(i);
	float3 barys;
	barys.xy = i.barycentricCoordinates;
	barys.z = 1 - barys.x - barys.y;								// 由于重心坐标三个值相加是1，所以这里可以算出第三个分量
	float3 deltas = fwidth(barys);									// 找到自己与旁边像素的重心的差值， 相当于float3 deltas = abs(ddx(barys)) + abs(ddy(barys));
	float3 smoothing = deltas * _WireframeSmoothing;
	float3 thickness = deltas * _WireframeThickness;
	barys = smoothstep(thickness, thickness + smoothing, barys);	// smoothstep若参数3在参数1~参数2的范围内，则返回0~1的过渡值，如果参数3大于参数2，则返回1，小于参数1则返回0
	float minBary = min(barys.x, min(barys.y, barys.z));			// 找到最小的分量，该分量代表自身片元到三角面三条边的最短距离
	return lerp(_WireframeColor, albedo, minBary);
}
#define ALBEDO_FUNCTION GetAlbedoWithWireframe

#include "CustomLighting.cginc"

struct InterpolatorsGeometry{
	InterpolatorsVertex data;
	CUSTOM_GEOMETRY_INTERPOLATORS		
};

// 几何着色器
[maxvertexcount(3)] // 表明输出多少个顶点
void MyGeometryProgram(triangle InterpolatorsVertex i[3], inout TriangleStream<InterpolatorsGeometry> stream) // 参数1类型：triangle表明输入的图元是三角面
{
	float3 p0 = i[0].worldPos.xyz;
	float3 p1 = i[1].worldPos.xyz;
	float3 p2 = i[2].worldPos.xyz;

	float3 triangleNormal = normalize(cross((p1 - p0), (p2 - p0)));
	i[0].normal = triangleNormal;
	i[1].normal = triangleNormal;
	i[2].normal = triangleNormal;

	InterpolatorsGeometry g0, g1, g2;
	g0.data = i[0];
	g1.data = i[1];
	g2.data = i[2];
	
	g0.barycentricCoordinates = float2(1, 0);
	g1.barycentricCoordinates = float2(0, 1);
	g2.barycentricCoordinates = float2(0, 0);

	stream.Append(g0);
	stream.Append(g1); 
	stream.Append(g2);
	
}
#endif