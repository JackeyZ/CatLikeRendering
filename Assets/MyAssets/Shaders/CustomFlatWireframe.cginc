// ƽ̹���߿���ɫ��������ɫ����
#if !defined(FLAT_WIREFRAME_INCLUDED)
#define FLAT_WIREFRAME_INCLUDED

// ��������ƬԪ����������������ϵ�µ����꣬�������Ŀռ����������������1����������ֻ��Ҫ����������float2���Ϳ�����
// ��������ϵ������c��������(1/3,1/3,1/3), ƬԪԽ��������1����xԽ����1, ƬԪԽ��������2����yԽ����1
#define CUSTOM_GEOMETRY_INTERPOLATORS float2 barycentricCoordinates : TEXCOORD9;

#include "CustomLightingInput.cginc"

float3 _WireframeColor;												// �߿���ɫ
float _WireframeSmoothing;											// �߿���������ȣ����أ�
float _WireframeThickness;											// �߿��ȣ����أ�

// ��дcustom lighting input.cginc��ķ���
float3 GetAlbedoWithWireframe(Interpolators i)
{
	float3 albedo = GetAlbedo(i);
	float3 barys;
	barys.xy = i.barycentricCoordinates;
	barys.z = 1 - barys.x - barys.y;								// ����������������ֵ�����1��������������������������
	float3 deltas = fwidth(barys);									// �ҵ��Լ����Ա����ص����ĵĲ�ֵ�� �൱��float3 deltas = abs(ddx(barys)) + abs(ddy(barys));
	float3 smoothing = deltas * _WireframeSmoothing;
	float3 thickness = deltas * _WireframeThickness;
	barys = smoothstep(thickness, thickness + smoothing, barys);	// smoothstep������3�ڲ���1~����2�ķ�Χ�ڣ��򷵻�0~1�Ĺ���ֵ���������3���ڲ���2���򷵻�1��С�ڲ���1�򷵻�0
	float minBary = min(barys.x, min(barys.y, barys.z));			// �ҵ���С�ķ������÷�����������ƬԪ�������������ߵ���̾���
	return lerp(_WireframeColor, albedo, minBary);
}
#define ALBEDO_FUNCTION GetAlbedoWithWireframe

#include "CustomLighting.cginc"

struct InterpolatorsGeometry{
	InterpolatorsVertex data;
	CUSTOM_GEOMETRY_INTERPOLATORS		
};

// ������ɫ��
[maxvertexcount(3)] // ����������ٸ�����
void MyGeometryProgram(triangle InterpolatorsVertex i[3], inout TriangleStream<InterpolatorsGeometry> stream) // ����1���ͣ�triangle���������ͼԪ��������
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