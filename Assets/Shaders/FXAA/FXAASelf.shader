Shader "FXAASelf" {
	Properties {
		_MainTex ("Texture", 2D) = "white" {}
	}

	CGINCLUDE
		#include "UnityCG.cginc"

		sampler2D _MainTex;
		float4 _MainTex_TexelSize;

		float _ContrastThreshold, _RelativeThreshold;

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
			float2 TexelSize = _MainTex_TexelSize.xy;
			float4 Origin = tex2D(_MainTex, UV);
			float M  = Luminance(Origin);
			float E  = Luminance(tex2D(_MainTex, UV + float2( TexelSize.x,            0)));
			float N  = Luminance(tex2D(_MainTex, UV + float2(           0,  TexelSize.y)));
			float W  = Luminance(tex2D(_MainTex, UV + float2(-TexelSize.x,            0)));
			float S  = Luminance(tex2D(_MainTex, UV + float2(           0, -TexelSize.y)));
			float NW = Luminance(tex2D(_MainTex, UV + float2(-TexelSize.x,  TexelSize.y)));
			float NE = Luminance(tex2D(_MainTex, UV + float2( TexelSize.x,  TexelSize.y)));
			float SW = Luminance(tex2D(_MainTex, UV + float2(-TexelSize.x, -TexelSize.y)));
			float SE = Luminance(tex2D(_MainTex, UV + float2( TexelSize.x, -TexelSize.y)));

			//计算出对比度的值
			float MaxLuma = max(max(max(N, E), max(W, S)), M);
			float MinLuma = min(min(min(N, E), min(W, S)), M);
			float Contrast =  MaxLuma - MinLuma;

			//如果对比度值很小，认为不需要进行抗锯齿，直接跳过抗锯齿计算
			if(Contrast < max(_ContrastThreshold, MaxLuma * _RelativeThreshold))
			{
				return Origin;
			}

			// 先计算出锯齿的方向，是水平还是垂直方向
			float Vertical   = abs(N + S - 2 * M) * 2 + abs(NE + SE - 2 * E) + abs(NW + SW - 2 * W);
			float Horizontal = abs(E + W - 2 * M) * 2 + abs(NE + NW - 2 * N) + abs(SE + SW - 2 * S);
			bool IsHorizontal = Vertical > Horizontal;
			//混合的方向
			float2 PixelStep = IsHorizontal ? float2(0, TexelSize.y) : float2(TexelSize.x, 0);
			// 确定混合方向的正负值
			float Positive = abs((IsHorizontal ? N : E) - M);
			float Negative = abs((IsHorizontal ? S : W) - M);
			// if(Positive < Negative) PixelStep = -PixelStep;
			// 算出锯齿两侧的亮度变化的梯度值
			float Gradient, OppositeLuminance;
			if(Positive > Negative) {
			    Gradient = Positive;
			    OppositeLuminance = IsHorizontal ? N : E;
			} else {
			    PixelStep = -PixelStep;
			    Gradient = Negative;
			    OppositeLuminance = IsHorizontal ? S : W;
			}

			
			// 这部分是基于亮度的混合系数计算
			float Filter = 2 * (N + E + S + W) + NE + NW + SE + SW;
			Filter = Filter / 12;
			Filter = abs(Filter -  M);
			Filter = saturate(Filter / Contrast);
			// 基于亮度的混合系数值
			float PixelBlend = smoothstep(0, 1, Filter);
			PixelBlend = PixelBlend * PixelBlend;
			
			// 下面是基于边界的混合系数计算
			float2 UVEdge = UV;
			UVEdge += PixelStep * 0.5f;
			float2 EdgeStep = IsHorizontal ? float2(TexelSize.x, 0) : float2(0, TexelSize.y);

			// 这里是定义搜索的步长，步长越长，效果自然越好
			#define _SearchSteps 15
			// 未搜索到边界时，猜测的边界距离
			#define _Guess 8

			// 沿着锯齿边界两侧，进行搜索，找到锯齿的边界
			float EdgeLuminance = (M + OppositeLuminance) * 0.5f;
			float GradientThreshold = Gradient * 0.25f;
			float PLuminanceDelta, NLuminanceDelta, PDistance, NDistance;
			int i;
			UNITY_UNROLL
			for(i = 1; i <= _SearchSteps; ++i) {
			    PLuminanceDelta = Luminance(tex2D(_MainTex, UVEdge + i * EdgeStep)) - EdgeLuminance;
			    if(abs(PLuminanceDelta) > GradientThreshold) {
			        PDistance = i * (IsHorizontal ? EdgeStep.x : EdgeStep.y);
			        break;
			    }
			}
			if(i == _SearchSteps + 1) {
			    PDistance = EdgeStep * _Guess;
			}
			UNITY_UNROLL
			for(i = 1; i <= _SearchSteps; ++i) {
			    NLuminanceDelta = Luminance(tex2D(_MainTex, UVEdge - i * EdgeStep)) - EdgeLuminance;
			    if(abs(NLuminanceDelta) > GradientThreshold) {
			        NDistance = i * (IsHorizontal ? EdgeStep.x : EdgeStep.y);
			        break;
			    }
			}
			if(i == _SearchSteps + 1) {
			    NDistance = EdgeStep * _Guess;
			}

			float EdgeBlend;
			// 这里是计算基于边界的混合系数，如果边界方向错误，直接设为0，如果方向正确，按照相对的距离来估算混合系数
			if (PDistance < NDistance) {
				if(sign(PLuminanceDelta) == sign(M - EdgeLuminance)) {
			        EdgeBlend = 0;
			    } else {
			        EdgeBlend = 0.5f - PDistance / (PDistance + NDistance);
			    }
			} else {
			    if(sign(NLuminanceDelta) == sign(M - EdgeLuminance)) {
			        EdgeBlend = 0;
			    } else {
			        EdgeBlend = 0.5f - NDistance / (PDistance + NDistance);
			    }
			}

			//从两种混合系数中，取最大的那个
			float FinalBlend = max(PixelBlend, EdgeBlend);
			float4 Result = tex2D(_MainTex, UV + PixelStep * FinalBlend);
			return Result;
		}

		float4 FXAAConsoleFragement(Interpolators interpolators) : SV_Target
		{
			float2 UV = interpolators.uv;
			float2 TexelSize = _MainTex_TexelSize.xy;
			float4 Origin = tex2D(_MainTex, UV);
			float M  = Luminance(Origin);
			float NW = Luminance(tex2D(_MainTex, UV + float2(-TexelSize.x,  TexelSize.y) * 0.5));
			float NE = Luminance(tex2D(_MainTex, UV + float2( TexelSize.x,  TexelSize.y) * 0.5));
			float SW = Luminance(tex2D(_MainTex, UV + float2(-TexelSize.x, -TexelSize.y) * 0.5));
			float SE = Luminance(tex2D(_MainTex, UV + float2( TexelSize.x, -TexelSize.y) * 0.5));

			float MaxLuma = max(max(NW, NE), max(SW, SE));
			float MinLuma = min(min(NW, NE), min(NW, NE));
			float Contrast = max(MaxLuma, M) -  min(MinLuma, M);
			
			//如果对比度值很小，认为不需要进行抗锯齿，直接跳过抗锯齿计算
			if(Contrast < max(_ContrastThreshold, MaxLuma * _RelativeThreshold))
			{
				return Origin;
			}
			NE += 1.0f / 384.0f;
			float2 Dir;
			Dir.x = -((NW + NE) - (SW + SE));
			Dir.y = ((NE + SE) - (NW + SW));
			Dir = normalize(Dir);
			
			#define _Scale 0.5
			float2 Dir1 = Dir * _MainTex_TexelSize.xy * _Scale;

			float4 N1 = tex2D(_MainTex, UV - Dir1);
			float4 P1 = tex2D(_MainTex, UV + Dir1);
			float4 Result = (N1 + P1) * 0.5;

			#define _Sharpness 8
			float DirAbsMinTimesC = min(abs(Dir1.x), abs(Dir1.y)) * _Sharpness;
			float2 Dir2 = clamp(Dir1.xy / DirAbsMinTimesC, -2.0, 2.0) * 2;
			float4 N2 = tex2D(_MainTex, UV - Dir2 * _MainTex_TexelSize.xy);
			float4 P2 = tex2D(_MainTex, UV + Dir2 * _MainTex_TexelSize.xy);
			float4 Result2 = Result * 0.5f + (N2 + P2) * 0.25f;
			// 如果新的结果，亮度在正确范围内，则使用新的结果
			float NewLum = Luminance(Result2);
			if((NewLum >= MinLuma) && (NewLum <= MaxLuma)) {
			    Result = Result2;
			}
			return Result;
		}
	ENDCG

	SubShader {
		Cull Off
		ZTest Always
		ZWrite Off

		Pass { // FXAA QUALITY版本
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FXAAQualityFragement
			ENDCG
		}
		
		Pass { // FXAA CONSOLE版本
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FXAAConsoleFragement
			ENDCG
		}
	}
}