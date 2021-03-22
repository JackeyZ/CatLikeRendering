// 曲面细分着色器
// 解析blog.csdn.net/ifenghua135792468/article/details/106851708

#if !defined(TESSELLATION_INCLUDED)
#define TESSELLATION_INCLUDED

	float _TessellationUniform;					// 细分程度
	float _TessellationEdgeLength;				// 边上每隔多远分割一段

	struct TessellationControlPoint{
	    float4 vertex : INTERNALTESSPOS;
		float3 normal : NORMAL;

		// 检查是否需要用到切线（例如，计算光照的pass里需要，而计算阴影的pass不需要）
		#if TESSELLATION_TANGENT
			float4 tangent : TANGENT;
		#endif

		float2 uv : TEXCOORD0;

		// 检查是否需要用到uv1
		#if TESSELLATION_UV1
			float2 uv1 : TEXCOORD1;                 // 静态光照贴图uv（LIGHTMAP_ON关键字启用的时候有效）
		#endif
		
		// 检查是否需要用到uv2
		#if TESSELLATION_UV2
			float2 uv2 : TEXCOORD2;                 // 动态光照贴图uv（DYNAMICLIGHTMAP_ON关键字启用的时候有效）
		#endif
	};

	struct TessellationFactors{
		float edge[3] : SV_TessFactor;			// 三角面三条边的因子
		float inside : SV_InsideTessFactor;		// 三角面内部因子
	};

	// 顶点着色器，在这里仅仅用来传递数据，真正的顶点计算放在细分之后的域着色器（MyDomainProgram）中
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


	// 外壳着色阶段（Hull）,在顶点着色器之后执行
	// patch：面片，当处理三角面的时候，patch是一个三角面（三个顶点）。当处理四边形的时候，patch是一个四边形（四个顶点）
	// hull程序的工作是将所需要的顶点数据传送给细分阶段，尽管参数1有整个patch，但该函数一次应仅输出一个顶点，patch中的每个顶点都会调用该函数一次。参数2则是记录着本次处理的顶点下标，对于patch数组的索引
	[UNITY_domain("tri")]									// 表明处理的是三角面
	[UNITY_outputcontrolpoints(3)]							// 表明输出三个控制点
	[UNITY_outputtopology("triangle_cw")]					// 三角面顶点以顺时针方向作为正面（与unity一致）
	[UNITY_partitioning("fractional_odd")]					// 告知GPU以分数奇数的方式分割patch(integer是整数)
	[UNITY_patchconstantfunc("MyPatchConstantFunction")]	// GPU要知道应该把patch分成多少份，这里提供一个返回细分层次因数的函数
	TessellationControlPoint MyHullProgram(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID){		// 处理三角面的时候，参数1：patch是三个顶点。参数2：是本次需要处理的顶点下标，即patch数组的下标
		return patch[id];
	}

	// 计算每个边上需要分割多少份(cp0和cp1是边的两个顶点（控制点）)
	float TessellationEdgeFactor(float3 cp0, float3 cp1){
		#if defined(_TESSELLATION_EDGE)
			float edgeLength = distance(cp0, cp1);								// 计算世界空间下的边长
			float3 edgeCenter = (cp0 + cp1) * 0.5;
			float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);	// 边中点到摄像机的距离（视距）
			return edgeLength * _ScreenParams.y / (_TessellationEdgeLength * viewDistance);		// 视距越远，细分程度越低， _ScreenParams.y是屏幕高度（分辨率越高细分程度越大）
		#else
			return _TessellationUniform;
		#endif
	}
	
	// 判断三角形是否在视锥体对应的平面外
	bool TriangleIsBelowClipPlane(float3 p0, float3 p1, float3 p2, int planeIndex, float bias){
		// unity_CameraWorldClipPlanes是世界空间下摄像机视锥体的六个平面（左右下上近远），前三个分量xyz表示法线（法线指向视锥体内部），第四个分量是平面到原点的垂直距离（偏移，有正有负）
		float4 panel = unity_CameraWorldClipPlanes[planeIndex];
		// 把原点到三角面顶点的向量投影到平面的法向量上，并且第四个分量设为1，与平面第四个分量相乘后刚好是偏移值，与投影相加后就可以得出点在面的下方还是上方
		// 三个顶点都在平面的下方，则表示在平面外
		// bias:偏移值，避免细分的顶点发生偏移，但原始顶点并没有偏移，造成剔除了视野内的细分顶点
		return dot(float4(p0, 1), panel) < bias && dot(float4(p1, 1), panel) < bias && dot(float4(p2, 1), panel) < bias;
	}

	// 判断是否需要裁剪掉三角形
	bool TriangleIsCulled(float3 p0, float3 p1, float3 p2, float bias){
		// 三角面在任意一个平面外，就表示这个三角面可以剔除，仅检查左右下上，四个平面就足够了
		return TriangleIsBelowClipPlane(p0, p1, p2, 0, bias) || 
				TriangleIsBelowClipPlane(p0, p1, p2, 1, bias) || 
				TriangleIsBelowClipPlane(p0, p1, p2, 2, bias) || 
				TriangleIsBelowClipPlane(p0, p1, p2, 3,  bias);
	}

	// 在这里通过设置细分层次因数（TessellationFactors），告诉GPU要如何划分patch(这里用的是三角面)
	// 每个patch（面片）运行一次
	TessellationFactors MyPatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch){
		float3 p0 = mul(unity_ObjectToWorld, patch[0].vertex).xyz;
		float3 p1 = mul(unity_ObjectToWorld, patch[1].vertex).xyz;
		float3 p2 = mul(unity_ObjectToWorld, patch[2].vertex).xyz;
		TessellationFactors f;

		float bias = 0;
		// 检查是否启用了顶点偏移
		#if VERTEX_DISPLACEMENT
			 bias = -0.5f * _DisplacementStrength;
		#endif

		// 判断是否剔除该三角形
		if(TriangleIsCulled(p0, p1, p2, bias)){
			f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0;
		}
		else{
			f.edge[0] = TessellationEdgeFactor(p1, p2);	// 三角面的一条边分成多少份, edge[0]控制的是第一个顶点的对边，即p1->p2
			f.edge[1] = TessellationEdgeFactor(p2, p0);
			f.edge[2] = TessellationEdgeFactor(p0, p1);

			//f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) * (1 / 3.0);
			// 在OpenGlCore的情况下，需要重复调用TessellationEdgeFactor方法，不然在OpenGlCore编译之后，f.edge和f.inside会分开两个方法计算, 
			// 造成只使用f.edge[2]相加来计算平均数，会出现错误, 具体看编译后的代码
			f.inside = (TessellationEdgeFactor(p1, p2) + TessellationEdgeFactor(p2, p0) + TessellationEdgeFactor(p0, p1	)) * (1 / 3.0);		
		}
		return f;
	}

	// 域着色器，从hull着色器确定细分方式之后，经过细分的顶点会逐个调用该着色器，由该着色器根据细分因数计算并生成最终的顶点，域着色器相当于镶嵌阶段细分后顶点的顶点着色器
	// factors是细分因数
	// patch是原始三角面
	// barycentricCoordinates是重心坐标(三个分量分别是本次处理的顶点对应patch三角面三个顶点的权重，且三个分量相加等于1。哪个分量权重越大，表示本次处理的顶点越靠近它)
	[UNITY_domain("tri")]
	InterpolatorsVertex MyDomainProgram(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation){
		TessellationControlPoint data;

		// 定义一个计算新顶点插值信息的宏，例：用原生三角面的顶点坐标分别乘以重心坐标的三个分量即可得出新建顶点的坐标，uv等计算方式一样
		#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x \
		+ patch[1].fieldName * barycentricCoordinates.y \
		+ patch[2].fieldName * barycentricCoordinates.z;
		
		// 计算新建顶点的各种插值信息
		MY_DOMAIN_PROGRAM_INTERPOLATE(vertex);			// 顶点坐标
		MY_DOMAIN_PROGRAM_INTERPOLATE(normal);			// 法线

		#if TESSELLATION_TANGENT
			MY_DOMAIN_PROGRAM_INTERPOLATE(tangent);		// 切线
		#endif

		MY_DOMAIN_PROGRAM_INTERPOLATE(uv);

		#if TESSELLATION_UV1
			MY_DOMAIN_PROGRAM_INTERPOLATE(uv1);
		#endif

		#if TESSELLATION_UV2
			MY_DOMAIN_PROGRAM_INTERPOLATE(uv2);
		#endif	 

		return MyVertexProgram(data);					// 因为该函数返回的值直接传给几何着色器或者插值器了，这里直接调用原始顶点的顶点函数进行计算
	}


#endif


