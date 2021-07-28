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
        Texture2D _BlendTex;
        float4 _MainTex_TexelSize;
    
        SamplerState sampler_LinearClamp;
        SamplerState sampler_PointClamp;
        

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

                float4 Frag(Varyings i) : SV_Target
                {
                    return _MainTex.Sample(sampler_LinearClamp, i.texcoord);
                }
                #pragma vertex Vert
                #pragma fragment Frag

            ENDHLSL
        }
    }
}
