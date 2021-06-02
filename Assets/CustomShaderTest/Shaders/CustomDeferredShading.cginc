#if !defined(CUSTOM_DEFERRED_SHADING)
#define CUSTOM_DEFERRED_SHADING

//#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;
sampler2D _CameraGBufferTexture4;	// 阴影遮罩

float4 _LightColor, _LightDir;      // 直接光颜色及其方向
float4 _LightPos;                   // 非方向光会有一个光源位置, rgb是坐标，w是光照距离
float _LightAsQuad;                 // 当前在处理的是四边形的时候，也就是直射光，值为1，否则值为0

#if defined(POINT_COOKIE)
    samplerCUBE _LightTexture0;     // 点光源的cookie纹理
#else
    sampler2D _LightTexture0;       // 光源的cookie纹理
#endif
sampler2D _LightTextureB0;          // 光源的衰减纹理（非直射光才有）
float4x4 unity_WorldToLight;        // 世界空间到光源空间的转换矩阵

// 判断是否启用了屏幕空间阴影
#if defined(SHADOWS_SCREEN)
    sampler2D _ShadowMapTexture;	// 声明屏幕空间阴影贴图
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

// 获取阴影遮罩
float GetShadowMaskAttenuation(float2 uv)
{
	float attenuation = 1;
	// 判断是否启用了阴影遮罩贴图
	#if defined(SHADOWS_SHADOWMASK)
		float4 mask = tex2D(_CameraGBufferTexture4, uv);					// 对gBuffer里面的阴影遮罩进行采样
        // 四个灯光对应mask的四个通道
		// unity_OcclusionMaskSelector用于表明当前正在被渲染的是第几个灯光。
		// 即如果当前渲染的灯光是第一个灯光，则unity_OcclusionMaskSelector的数值为(1, 0, 0, 0)
        // 点乘后，选择出与当前灯光对应的通道值
		attenuation = saturate(dot(mask, unity_OcclusionMaskSelector));		
	#endif
	return attenuation;
}

// 直接光(viewZ是个正数，不是视口空间下的z值，视口空间下的z值是负的)
UnityLight CreateLight(float2 uv, float3 worldPos, float viewZ){
    UnityLight light;              // 直接光
    float attenuation = 1;
    float shadowAttenuation = 1;
    bool shadowed = false;

    // 如果是方向光
    #if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
        light.dir = -_LightDir;        // 光源到片元的向量转换成片元到光源的向量
        // 是否有直射光遮罩
        #if defined(DIRECTIONAL_COOKIE)
            float2 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xy;
            attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie, 0, -8)).w;            // -8是mipmap级别偏移,避免不同片元提取不同mipmap级别的纹理导致衔接有问题
        #endif

        // 判断是否启用了屏幕空间阴影
        #if defined(SHADOWS_SCREEN)
            shadowed = true;
            shadowAttenuation = tex2D(_ShadowMapTexture, uv).r;                             // 对屏幕空间阴影贴图采样，获得阴影，1表示没有阴影
        #endif
    #else
        float3 lightVec = _LightPos.xyz - worldPos;
        light.dir = normalize(lightVec);

        // 距离衰减
        attenuation *= tex2D(_LightTextureB0, (dot(lightVec, lightVec) * _LightPos.w).rr).UNITY_ATTEN_CHANNEL;       // 用（距离的平方*光照范围）采样距离衰减， 不同平台衰减储存在不同通道（UNITY_ATTEN_CHANNEL）

        // 聚光灯cookie
        #if defined(SPOT)
            float4 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1));
            // 因为是聚光灯，拥有透视变换，所以这里用透视除法，得到真正的uv
            uvCookie.xy /= uvCookie.w;      
            attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie.xy, 0, -8)).w;
            attenuation *= uvCookie.w < 0;  // 聚光灯后方不产生光锥（因为齐次坐标下w = -z，而z为正的时候在聚光灯背面，所以w为负的时候在聚光灯的背面）
            
            // 判断聚光灯是否投射阴影
            #if defined(SHADOWS_DEPTH)
                shadowed = true;
                shadowAttenuation = UnitySampleShadowmap(mul(unity_WorldToShadow[0], float4(worldPos, 1)));     // 对阴影贴图进行采样，需要传入一个阴影空间坐标，unity_WorldToShadow[0]可以把坐标从世界空间转换到阴影空间
            #endif
        #else
            // 点光源cookie
            #if defined(POINT_COOKIE)
                float3 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xyz;     // 把世界空间坐标转换到光源空间
                attenuation *= texCUBEbias(_LightTexture0, float4(uvCookie, -8)).w;     // 对点光源cookie进行采样
            #endif
            // 立方阴影贴图（点光源）
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
        float shadowFadeDistance = UnityComputeShadowFadeDistance(worldPos, viewZ);     // 得到片元与阴影区域中心（衰减中心）的距离
        float shadowFade = UnityComputeShadowFade(shadowFadeDistance);                  // 根据片元到衰减中心的距离计算阴影衰减值,0~1，0表示不衰减，1表示全衰减(即没有阴影)
        //shadowAttenuation = saturate(shadowAttenuation + shadowFade);                 // 把阴影衰减应用到阴影值中
		shadowAttenuation = UnityMixRealtimeAndBakedShadows(shadowAttenuation, GetShadowMaskAttenuation(uv), shadowFade);  // 把阴影衰减和阴影遮罩应用到阴影值中

        // UNITY_FAST_COHERENT_DYNAMIC_BRANCHING 目标平台是否支持对连贯分支优化，支持的平台才使用以下的操作
        // 连贯分支：即大部分连续的片元都运行其中一个分支的代码（除了阴影区域的边缘附近，其他片元都落到阴影的内部或外部，即大部分是连贯的）
        // SHADOWS_SOFT 是否是软阴影（软阴影多次采样比较昂贵，所以下面用一个分支来优化）
        #if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT)
			// 未启用阴影遮罩才进行全衰减优化，因为如果启用了阴影遮罩，片元在超过阴影距离之后会读取阴影遮罩的值，不存在超过距离阴影衰减的情况
			#if !defined(SHADOWS_SHADOWMASK)
				// 分配一个动态分支，避免编译后弄了一个假分支，导致分支两边的逻辑都运行
				UNITY_BRANCH        
				// 判断衰减值是否是全衰减，如果是的话表明片元距离阴影衰减中心太远了，直接把阴影采样的值设成1，这样编译后的代码就不需要对阴影贴图进行采样了，优化性能
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
    i.uv = ComputeScreenPos(i.pos);                 // 裁剪空间齐次坐标转换为屏幕空间齐次坐标[-w, w] => [0, w]

    // 直射光情况，即绘制全屏四边形的时候， 法线传进来的是摄像机位置到近裁切面四个顶点的方向向量, _LightAsQuad数值为1
    // 如果不是直射光是其他3D形状，则要自己计算，_LightAsQuad数值为0
    // * float3(-1, -1, 1)是为了配合片元着色器里面的计算rayToFarPlane的操作，因为视口空间下是右手坐标系，摄像机前的坐标z值都是负数，而_ProjectionParams.z是正数
    // 例如：当视口空间下坐标（-1， -1， -1）代入i.ray * _ProjectionParams.z / i.ray.z之后x和y会变成正数，方向反了，所以这里提前反转一下x和y。而* float3（1, 1, -1）也能达到不让x和y反转的目的
    i.ray = lerp(UnityObjectToViewPos(v.vertex) * float3(-1, -1, 1), v.normal, _LightAsQuad);

    return i;
}

float4 FragmentProgram(Interpolators i) : SV_Target
{ 
    float2 uv = i.uv.xy / i.uv.w;                                   // 通过齐次除法得到真正的uv
    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
    depth = Linear01Depth(depth);
    // 摄像机到远裁切面四个顶点的方向向量
    float3 rayToFarPlane = i.ray * _ProjectionParams.z / i.ray.z;  // i.ray是摄像机到近裁切面各片元的方向向量，在这里转换为摄像机到远裁切面各片元的方向向量，_ProjectionParams.z是摄像机到远裁切面的距离（一个正值）
                                                                   // 由于i,ray.z是一个负数，所以此时得到的rayToFarPlane的z值是正值

    // 视口空间下的片元坐标,但z值变成了正数，所以相当于左手坐标系了
    float3 viewPos = rayToFarPlane * depth; 
    // 世界空间下的片元坐标
    float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz; // unity_CameraToWorld字面上看是从视口空间转换到世界空间，但这里的视口空间是左手坐标系，即摄像机前方的z值是正数
    // 世界空间下的摄像机到片元的方向向量（视线方向）
    float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);
    
    // 从GBuffer里面提取光照数据（数据对应CuistomLighting里面FragmentOutPut结构体的延迟渲染部分）
    float3 albedo = tex2D(_CameraGBufferTexture0, uv).rgb;
    float3 specularTint = tex2D(_CameraGBufferTexture1, uv).rgb;
    float3 smoothness = tex2D(_CameraGBufferTexture1, uv).a;
    float3 normal = tex2D(_CameraGBufferTexture2, uv).rgb * 2 - 1;
    // 1-高光反射反射率
    float oneMinusReflectivity = 1 - SpecularStrength(specularTint);        // SpecularStrength函数用于得到三个颜色分量（rgb）中的最大值

    UnityLight light = CreateLight(uv, worldPos, viewPos.z);                // 直接光

    UnityIndirect indirectLight;                                            // 间接光
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    float4 color = UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity, smoothness, normal, viewDir, light, indirectLight);

    // 检查摄像机是否用的LDR
    #if !defined(UNITY_HDR_ON)
        color = exp2(-color);   // 对光照颜色进行编码，LDR下会对应在DefferredShading.shader里的第二个pass用了log2进行解码
    #endif

    return color;
}

#endif