Shader "SMAANVIDIA"
{
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }
    HLSLINCLUDE
        #pragma exclude_renderers gles
        #include "../Stdlib.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        TEXTURE2D_SAMPLER2D(_BlendTex, sampler_BlendTex);
        TEXTURE2D_SAMPLER2D(_AreaTex, sampler_AreaTex);
        TEXTURE2D_SAMPLER2D(_SearchTex, sampler_SearchTex);
        float4 _MainTex_TexelSize;
        SamplerState sampler_LinearClamp;
        SamplerState sampler_PointClamp;
        
        #define SMAA_RT_METRICS _MainTex_TexelSize
        #define SMAA_AREATEX_SELECT(s) s.rg
        #define SMAA_SEARCHTEX_SELECT(s) s.a
        #define LinearSampler sampler_LinearClamp
        #define PointSampler sampler_PointClamp

        #include "SubpixelMorphologicalAntialiasing.hlsl"
        struct Attributes
        {
            float3 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // Edge detection
        Pass
        {

            HLSLPROGRAM
                struct VaryingsEdge
                {
                    float4 vertex : SV_POSITION;
                    float2 texcoord : TEXCOORD0;
                    float4 offsets[3] : TEXCOORD1;
                };
                VaryingsEdge VertEdge(Attributes v)
                {
                    VaryingsEdge o;
                    o.vertex = mul(unity_MatrixVP, mul(unity_ObjectToWorld, float4(v.vertex, 1.0)));
                    o.texcoord = v.uv;
                    SMAAEdgeDetectionVS(o.texcoord, o.offsets);
                    return o;
                }

                float4 FragEdge(VaryingsEdge i) : SV_Target
                {
                    return float4(SMAAColorEdgeDetectionPS(i.texcoord, i.offsets, _MainTex), 0.0, 0.0);
                }
                #pragma vertex VertEdge
                #pragma fragment FragEdge

            ENDHLSL
        }

        // Blend Weights Calculation
        Pass
        {

            HLSLPROGRAM
                struct VaryingsBlend
                {
                    float4 vertex : SV_POSITION;
                    float2 texcoord : TEXCOORD0;
                    float2 pixcoord : TEXCOORD1;
                    float4 offsets[3] : TEXCOORD2;
                };
                VaryingsBlend VertBlend(Attributes v)
                {
                    VaryingsBlend o;
                    o.vertex = mul(unity_MatrixVP, mul(unity_ObjectToWorld, float4(v.vertex, 1.0)));
                    o.texcoord = v.uv;
                    SMAABlendingWeightCalculationVS(o.texcoord, o.pixcoord, o.offsets);
                    return o;
                }

                float4 FragBlend(VaryingsBlend i) : SV_Target
                {
                    return SMAABlendingWeightCalculationPS(i.texcoord, i.pixcoord, i.offsets, _MainTex, _AreaTex, _SearchTex, 0);
                }
                #pragma vertex VertBlend
                #pragma fragment FragBlend

            ENDHLSL
        }

        // Neighborhood Blending
        Pass
        {
            HLSLPROGRAM
                struct VaryingsNeighbor
                {
                    float4 vertex : SV_POSITION;
                    float2 texcoord : TEXCOORD0;
                    float4 offset : TEXCOORD1;
                };
                VaryingsNeighbor VertNeighbor(Attributes v)
                {
                    VaryingsNeighbor o;
                    o.vertex = mul(unity_MatrixVP, mul(unity_ObjectToWorld, float4(v.vertex, 1.0)));
                    o.texcoord = v.uv;
                    SMAANeighborhoodBlendingVS(o.texcoord, o.offset);
                    return o;
                }

                float4 FragNeighbor(VaryingsNeighbor i) : SV_Target
                {
                    return SMAANeighborhoodBlendingPS(i.texcoord, i.offset, _MainTex, _BlendTex);
                }
                #pragma vertex VertNeighbor
                #pragma fragment FragNeighbor

            ENDHLSL
        }
    }
}
