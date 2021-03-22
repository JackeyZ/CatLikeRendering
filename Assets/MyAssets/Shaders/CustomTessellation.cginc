// ����ϸ����ɫ��
// ����blog.csdn.net/ifenghua135792468/article/details/106851708

#if !defined(TESSELLATION_INCLUDED)
#define TESSELLATION_INCLUDED

	float _TessellationUniform;					// ϸ�̶ֳ�
	float _TessellationEdgeLength;				// ����ÿ����Զ�ָ�һ��

	struct TessellationControlPoint{
	    float4 vertex : INTERNALTESSPOS;
		float3 normal : NORMAL;

		// ����Ƿ���Ҫ�õ����ߣ����磬������յ�pass����Ҫ����������Ӱ��pass����Ҫ��
		#if TESSELLATION_TANGENT
			float4 tangent : TANGENT;
		#endif

		float2 uv : TEXCOORD0;

		// ����Ƿ���Ҫ�õ�uv1
		#if TESSELLATION_UV1
			float2 uv1 : TEXCOORD1;                 // ��̬������ͼuv��LIGHTMAP_ON�ؼ������õ�ʱ����Ч��
		#endif
		
		// ����Ƿ���Ҫ�õ�uv2
		#if TESSELLATION_UV2
			float2 uv2 : TEXCOORD2;                 // ��̬������ͼuv��DYNAMICLIGHTMAP_ON�ؼ������õ�ʱ����Ч��
		#endif
	};

	struct TessellationFactors{
		float edge[3] : SV_TessFactor;			// �����������ߵ�����
		float inside : SV_InsideTessFactor;		// �������ڲ�����
	};

	// ������ɫ������������������������ݣ������Ķ���������ϸ��֮�������ɫ����MyDomainProgram����
	TessellationControlPoint MyTessellationVertexProgram(VertexData v)
	{ 
		TessellationControlPoint p;
		p.vertex = v.vertex;
		p.normal = v.normal;

		#if TESSELLATION_TANGENT
			p.tangent = v.tangent;
		#endif
		p.uv = v.uv;

		#if TESSELLATION_TANGENT
			p.uv1 = v.uv1;
		#endif

		#if TESSELLATION_TANGENT
			p.uv2 = v.uv2;
		#endif
		return p;
	}


	// �����ɫ�׶Σ�Hull��,�ڶ�����ɫ��֮��ִ��
	// patch����Ƭ���������������ʱ��patch��һ�������棨�������㣩���������ı��ε�ʱ��patch��һ���ı��Σ��ĸ����㣩
	// hull����Ĺ����ǽ�����Ҫ�Ķ������ݴ��͸�ϸ�ֽ׶Σ����ܲ���1������patch�����ú���һ��Ӧ�����һ�����㣬patch�е�ÿ�����㶼����øú���һ�Ρ�����2���Ǽ�¼�ű��δ���Ķ����±꣬����patch���������
	[UNITY_domain("tri")]									// �����������������
	[UNITY_outputcontrolpoints(3)]							// ��������������Ƶ�
	[UNITY_outputtopology("triangle_cw")]					// �����涥����˳ʱ�뷽����Ϊ���棨��unityһ�£�
	[UNITY_partitioning("fractional_odd")]					// ��֪GPU�Է��������ķ�ʽ�ָ�patch(integer������)
	[UNITY_patchconstantfunc("MyPatchConstantFunction")]	// GPUҪ֪��Ӧ�ð�patch�ֳɶ��ٷݣ������ṩһ������ϸ�ֲ�������ĺ���
	TessellationControlPoint MyHullProgram(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID){		// �����������ʱ�򣬲���1��patch���������㡣����2���Ǳ�����Ҫ����Ķ����±꣬��patch������±�
		return patch[id];
	}

	// ����ÿ��������Ҫ�ָ���ٷ�(cp0��cp1�Ǳߵ��������㣨���Ƶ㣩)
	float TessellationEdgeFactor(float3 cp0, float3 cp1){
		#if defined(_TESSELLATION_EDGE)
			float edgeLength = distance(cp0, cp1);								// ��������ռ��µı߳�
			float3 edgeCenter = (cp0 + cp1) * 0.5;
			float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);	// ���е㵽������ľ��루�Ӿࣩ
			return edgeLength * _ScreenParams.y / (_TessellationEdgeLength * viewDistance);		// �Ӿ�ԽԶ��ϸ�̶ֳ�Խ�ͣ� _ScreenParams.y����Ļ�߶ȣ��ֱ���Խ��ϸ�̶ֳ�Խ��
		#else
			return _TessellationUniform;
		#endif
	}
	
	// �ж��������Ƿ�����׶���Ӧ��ƽ����
	bool TriangleIsBelowClipPlane(float3 p0, float3 p1, float3 p2, int planeIndex, float bias){
		// unity_CameraWorldClipPlanes������ռ����������׶�������ƽ�棨�������Ͻ�Զ����ǰ��������xyz��ʾ���ߣ�����ָ����׶���ڲ��������ĸ�������ƽ�浽ԭ��Ĵ�ֱ���루ƫ�ƣ������и���
		float4 panel = unity_CameraWorldClipPlanes[planeIndex];
		// ��ԭ�㵽�����涥�������ͶӰ��ƽ��ķ������ϣ����ҵ��ĸ�������Ϊ1����ƽ����ĸ�������˺�պ���ƫ��ֵ����ͶӰ��Ӻ�Ϳ��Եó���������·������Ϸ�
		// �������㶼��ƽ����·������ʾ��ƽ����
		// bias:ƫ��ֵ������ϸ�ֵĶ��㷢��ƫ�ƣ���ԭʼ���㲢û��ƫ�ƣ�����޳�����Ұ�ڵ�ϸ�ֶ���
		return dot(float4(p0, 1), panel) < bias && dot(float4(p1, 1), panel) < bias && dot(float4(p2, 1), panel) < bias;
	}

	// �ж��Ƿ���Ҫ�ü���������
	bool TriangleIsCulled(float3 p0, float3 p1, float3 p2, float bias){
		// ������������һ��ƽ���⣬�ͱ�ʾ�������������޳���������������ϣ��ĸ�ƽ����㹻��
		return TriangleIsBelowClipPlane(p0, p1, p2, 0, bias) || 
				TriangleIsBelowClipPlane(p0, p1, p2, 1, bias) || 
				TriangleIsBelowClipPlane(p0, p1, p2, 2, bias) || 
				TriangleIsBelowClipPlane(p0, p1, p2, 3,  bias);
	}

	// ������ͨ������ϸ�ֲ��������TessellationFactors��������GPUҪ��λ���patch(�����õ���������)
	// ÿ��patch����Ƭ������һ��
	TessellationFactors MyPatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch){
		float3 p0 = mul(unity_ObjectToWorld, patch[0].vertex).xyz;
		float3 p1 = mul(unity_ObjectToWorld, patch[1].vertex).xyz;
		float3 p2 = mul(unity_ObjectToWorld, patch[2].vertex).xyz;
		TessellationFactors f;

		float bias = 0;
		// ����Ƿ������˶���ƫ��
		#if VERTEX_DISPLACEMENT
			 bias = -0.5f * _DisplacementStrength;
		#endif

		// �ж��Ƿ��޳���������
		if(TriangleIsCulled(p0, p1, p2, bias)){
			f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0;
		}
		else{
			f.edge[0] = TessellationEdgeFactor(p1, p2);	// �������һ���߷ֳɶ��ٷ�, edge[0]���Ƶ��ǵ�һ������ĶԱߣ���p1->p2
			f.edge[1] = TessellationEdgeFactor(p2, p0);
			f.edge[2] = TessellationEdgeFactor(p0, p1);

			//f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) * (1 / 3.0);
			// ��OpenGlCore������£���Ҫ�ظ�����TessellationEdgeFactor��������Ȼ��OpenGlCore����֮��f.edge��f.inside��ֿ�������������, 
			// ���ֻʹ��f.edge[2]���������ƽ����������ִ���, ���忴�����Ĵ���
			f.inside = (TessellationEdgeFactor(p1, p2) + TessellationEdgeFactor(p2, p0) + TessellationEdgeFactor(p0, p1	)) * (1 / 3.0);		
		}
		return f;
	}

	// ����ɫ������hull��ɫ��ȷ��ϸ�ַ�ʽ֮�󣬾���ϸ�ֵĶ����������ø���ɫ�����ɸ���ɫ������ϸ���������㲢�������յĶ��㣬����ɫ���൱����Ƕ�׶�ϸ�ֺ󶥵�Ķ�����ɫ��
	// factors��ϸ������
	// patch��ԭʼ������
	// barycentricCoordinates����������(���������ֱ��Ǳ��δ���Ķ����Ӧpatch���������������Ȩ�أ�������������ӵ���1���ĸ�����Ȩ��Խ�󣬱�ʾ���δ���Ķ���Խ������)
	[UNITY_domain("tri")]
	InterpolatorsVertex MyDomainProgram(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation){
		TessellationControlPoint data;

		// ����һ�������¶����ֵ��Ϣ�ĺ꣬������ԭ��������Ķ�������ֱ������������������������ɵó��½���������꣬uv�ȼ��㷽ʽһ��
		#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x \
		+ patch[1].fieldName * barycentricCoordinates.y \
		+ patch[2].fieldName * barycentricCoordinates.z;
		
		// �����½�����ĸ��ֲ�ֵ��Ϣ
		MY_DOMAIN_PROGRAM_INTERPOLATE(vertex);			// ��������
		MY_DOMAIN_PROGRAM_INTERPOLATE(normal);			// ����

		#if TESSELLATION_TANGENT
			MY_DOMAIN_PROGRAM_INTERPOLATE(tangent);		// ����
		#endif

		MY_DOMAIN_PROGRAM_INTERPOLATE(uv);

		#if TESSELLATION_UV1
			MY_DOMAIN_PROGRAM_INTERPOLATE(uv1);
		#endif

		#if TESSELLATION_UV2
			MY_DOMAIN_PROGRAM_INTERPOLATE(uv2);
		#endif	 

		return MyVertexProgram(data);					// ��Ϊ�ú������ص�ֱֵ�Ӵ���������ɫ�����߲�ֵ���ˣ�����ֱ�ӵ���ԭʼ����Ķ��㺯�����м���
	}


#endif


