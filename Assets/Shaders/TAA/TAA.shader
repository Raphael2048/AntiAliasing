Shader "TAA"
{
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }
    HLSLINCLUDE
        #pragma exclude_renderers gles
        #include "../Stdlib.hlsl"
        #include "../Colors.hlsl"

        Texture2D _MainTex;
        float4 _MainTex_TexelSize;
        Texture2D _HistoryTex;
        Texture2D _CameraDepthTexture;
        float4 _CameraDepthTexture_TexelSize;
        Texture2D _CameraMotionVectorsTexture;
        float4 _CameraMotionVectorsTexture_TexelSize;
        int _IgnoreHistory;
    
        SamplerState sampler_LinearClamp;
        SamplerState sampler_PointClamp;

        float2 _Jitter;

        struct Attributes
        {
            float3 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 vertex : SV_POSITION;
            float2 texcoord : TEXCOORD0;
        };

        Varyings Vert(Attributes v)
        {
            Varyings o;
            o.vertex = mul(unity_MatrixVP, mul(unity_ObjectToWorld, float4(v.vertex, 1.0)));
            o.texcoord = v.uv;
            return o; 
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM

                static const int2 kOffsets3x3[9] =
                {
	                int2(-1, -1),
	                int2( 0, -1),
	                int2( 1, -1),
	                int2(-1,  0),
                    int2( 0,  0),
	                int2( 1,  0),
	                int2(-1,  1),
	                int2( 0,  1),
	                int2( 1,  1),
                };
                float2 GetClosestFragment(float2 uv)
                {
                    float2 k = _CameraDepthTexture_TexelSize.xy;
                    const float4 neighborhood = float4(
                        SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, UnityStereoClamp(uv - k)),
                        SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, UnityStereoClamp(uv + float2(k.x, -k.y))),
                        SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, UnityStereoClamp(uv + float2(-k.x, k.y))),
                        SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, UnityStereoClamp(uv + k))
                    );
                #if defined(UNITY_REVERSED_Z)
                    #define COMPARE_DEPTH(a, b) step(b, a)
                #else
                    #define COMPARE_DEPTH(a, b) step(a, b)
                #endif
                    float3 result = float3(0.0, 0.0, SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_PointClamp, uv));
                    result = lerp(result, float3(-1.0, -1.0, neighborhood.x), COMPARE_DEPTH(neighborhood.x, result.z));
                    result = lerp(result, float3( 1.0, -1.0, neighborhood.y), COMPARE_DEPTH(neighborhood.y, result.z));
                    result = lerp(result, float3(-1.0,  1.0, neighborhood.z), COMPARE_DEPTH(neighborhood.z, result.z));
                    result = lerp(result, float3( 1.0,  1.0, neighborhood.w), COMPARE_DEPTH(neighborhood.w, result.z));
                    return (uv + result.xy * k);
                }
                float3 ClipHistory(float3 History, float3 BoxMin, float3 BoxMax)
                {
                    float3 Filtered = (BoxMin + BoxMax) * 0.5f;
                    float3 RayOrigin = History;
                    float3 RayDir = Filtered - History;
                    RayDir = abs( RayDir ) < (1.0/65536.0) ? (1.0/65536.0) : RayDir;
                    float3 InvRayDir = rcp( RayDir );
                
                    float3 MinIntersect = (BoxMin - RayOrigin) * InvRayDir;
                    float3 MaxIntersect = (BoxMax - RayOrigin) * InvRayDir;
                    float3 EnterIntersect = min( MinIntersect, MaxIntersect );
                    float ClipBlend = max( EnterIntersect.x, max(EnterIntersect.y, EnterIntersect.z ));
                    ClipBlend = saturate(ClipBlend);
                    return lerp(History, Filtered, ClipBlend);
                }
            
                float4 Frag(Varyings i) : SV_Target
                {
                    float2 uv = i.texcoord - _Jitter;
                    float4 Color = _MainTex.Sample(sampler_LinearClamp, uv);
                    //当没有上帧的历史数据，就直接使用当前帧的数据
                    if(_IgnoreHistory)
                    {
                        return Color;
                    }
                    float4 AABBMin, AABBMax;
                    AABBMax = AABBMin = Color;

                    for(int k = 0; k < 9; k++)
                    {
                        float4 C = _MainTex.Sample(sampler_PointClamp, uv, kOffsets3x3[k]);
                        AABBMin = min(AABBMin, C);
                        AABBMax = max(AABBMax, C);
                    }
                     
                    //因为镜头的移动会导致物体被遮挡关系变化，这步的目的是选择出周围距离镜头最近的点
                    float2 closest = GetClosestFragment(i.texcoord);
                    
                    //得到在屏幕空间中，和上帧相比UV偏移的距离
                    float2 Motion = SAMPLE_TEXTURE2D(_CameraMotionVectorsTexture, sampler_LinearClamp, closest).xy;
                    float4 HistoryColor = _HistoryTex.Sample(sampler_LinearClamp, i.texcoord - Motion);
                    
                    //根据AABB包围盒进行Clip计算:
                    HistoryColor.rgb = ClipHistory(HistoryColor.rgb, AABBMin.rgb, AABBMax.rgb);

                    //跟随速度变化混合系数
                    float BlendFactor = saturate(0.05 + length(Motion) * 100);
                    return lerp(HistoryColor, Color, BlendFactor);
                    
                    // return float4(motion, 0, 1);
                    
                    return _MainTex.Sample(sampler_LinearClamp, uv);
                }
                #pragma vertex Vert
                #pragma fragment Frag

            ENDHLSL
        }
    }
}
