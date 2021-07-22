Shader "FXAANVIDIA" {
	Properties {
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader {
		Cull Off
		ZTest Always
		ZWrite Off

		Pass { 
			CGPROGRAM
				// FXAA QUALITY版本
				#define FXAA_PC 1
				#define FXAA_HLSL_3 1
				// 为了使用方便，这里直接使用G通道作为颜色，否则需要一个额外的pass来计算亮度并写入到 A通道
				#define FXAA_GREEN_AS_LUMA 1
				#define FXAA_QUALITY__PRESET 39
				#include "UnityCG.cginc"

				// 这里是使用 NIVIDIA的FXAA3.11版本，前面宏定义的方式可参考文件内的注释说明
				#include "FXAA_3_11.hlsl"

				sampler2D _MainTex;
				float4 _MainTex_TexelSize;

				struct VertexData {
					float4 vertex : POSITION;
					float2 uv : TEXCOORD0;
				};

				struct Interpolators {
					float4 pos : SV_POSITION;
					float2 uv : TEXCOORD0;
				};

				Interpolators VertexProgram (VertexData v) {
					Interpolators i;
					i.pos = UnityObjectToClipPos(v.vertex);
					i.uv = v.uv;
					return i;
				}
				float4 FXAAQualityFragement(Interpolators interpolators) : SV_Target
				{
					float2 UV = interpolators.uv;
					// 请查看FXAA文件内部的说明，了解每个参数的含义
					return FxaaPixelShader(UV, 0, _MainTex, _MainTex, _MainTex, _MainTex_TexelSize.xy, 0, 0, 0,
		                0.75, 0.063, 0.0312, 0, 0, 0, 0);
				}
				#pragma vertex VertexProgram
				#pragma fragment FXAAQualityFragement
			ENDCG
		}
		
		Pass { 
			CGPROGRAM
				// FXAA CONSOLE版本	
				#define FXAA_PC_CONSOLE 1
				#define FXAA_HLSL_3 1
				#define FXAA_GREEN_AS_LUMA 1
				#define FXAA_QUALITY__PRESET 20
				#include "UnityCG.cginc"
				#include "FXAA_3_11.hlsl"

				sampler2D _MainTex;
				float4 _MainTex_TexelSize;

				struct VertexData {
					float4 vertex : POSITION;
					float2 uv : TEXCOORD0;
				};

				struct Interpolators {
					float4 pos : SV_POSITION;
					float2 uv  : TEXCOORD0;
				};

				Interpolators VertexProgram (VertexData v) {
					Interpolators i;
					i.pos = UnityObjectToClipPos(v.vertex);
					i.uv = v.uv;
					return i;
				}
				float4 FXAAConsoleFragement(Interpolators interpolators) : SV_Target
				{
					float2 UV = interpolators.uv;
					// 用来在四个对角处采样
					float4 POS = float4(UV, UV) + float4(-_MainTex_TexelSize.x, -_MainTex_TexelSize.y, _MainTex_TexelSize.x, _MainTex_TexelSize.y) * 0.5f;

					float4 RcpFrame = float4(-_MainTex_TexelSize.x, -_MainTex_TexelSize.y, _MainTex_TexelSize.x, _MainTex_TexelSize.y);
					//这部分计算也可以放到CPU中，作为 uniform参数传入
					// 这里乘的0.5是一个参数
					float4 RcpFrameOpt = RcpFrame * 0.5f;
					float4 RcpFrameOpt2 = RcpFrame * 2.0f;
					// 请查看FXAA文件内部的说明，了解每个参数对应的含义
					return FxaaPixelShader(UV, POS, _MainTex, _MainTex, _MainTex, 0, RcpFrameOpt, RcpFrameOpt2, 0,
		                0, 0, 0, 8, 0.125, 0.05, 0);
				}
				#pragma vertex VertexProgram
				#pragma fragment FXAAConsoleFragement
			ENDCG
		}
	}
}