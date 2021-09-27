Shader "SMAASelf"
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

        // 边缘检测
        Pass
        {
            HLSLPROGRAM

                float4 FragEdge(Varyings i) : SV_Target
                {
                    #define THRESHOLD 0.05f;
                    float2 uv = i.texcoord;
                    float2 size = _MainTex_TexelSize.xy;
                    float IThis = Luminance(_MainTex.Sample(sampler_LinearClamp, uv));
                    float IL    = abs(Luminance(_MainTex.Sample(sampler_LinearClamp, uv + float2(-size.x, 0))) - IThis);
                    float IL2   = abs(Luminance(_MainTex.Sample(sampler_LinearClamp, uv + float2(-size.x * 2, 0))) - IThis);
                    float IR    = abs(Luminance(_MainTex.Sample(sampler_LinearClamp, uv + float2(size.x, 0))) - IThis);
                    float IT    = abs(Luminance(_MainTex.Sample(sampler_LinearClamp, uv + float2(0, -size.y))) - IThis);
                    float IT2   = abs(Luminance(_MainTex.Sample(sampler_LinearClamp, uv + float2(0, -size.y * 2))) - IThis);
                    float IB    = abs(Luminance(_MainTex.Sample(sampler_LinearClamp, uv + float2(0, size.y))) - IThis);

                    float CMAX = max(max(IL, IR), max(IT, IB));

                    //判断左侧边界
                    bool EL = IL > THRESHOLD;
                    EL = EL && IL > (max(CMAX, IL2) * 0.5);

                    //判断上侧边界
                    bool ET = IT > THRESHOLD;
                    ET = ET && IT > (max(CMAX, IT2) * 0.5);
                    return float4(EL ? 1 : 0, ET ? 1 : 0, 0, 0);
                }
                #pragma vertex Vert
                #pragma fragment FragEdge

            ENDHLSL
        }

        // 混合系数计算
        Pass
        {
            HLSLPROGRAM
                // 圆角系数, 保留物体实际的边缘; 若为0 表示全保留, 为1表示不变
                #define ROUNDING_FACTOR 0.25
                // 最大搜索步长
                #define MAXSTEPS 10


                // 沿着左侧进行边界搜索
                float SearchXLeft(float2 coord)
                {
                    coord -= float2(1.5f, 0);
                    float e = 0;
                    int i = 0;
                    UNITY_UNROLL
                    for(; i < MAXSTEPS; i++)
                    {
                        e = _MainTex.Sample(sampler_LinearClamp, coord * _MainTex_TexelSize.xy).g;
                        [flatten]
                        if (e < 0.9f)  break;
                        coord -= float2(2, 0);
                    }
                    return min(2.0 * (i +  e), 2.0 * MAXSTEPS);
                }

                float SearchXRight(float2 coord)
                {
                    coord += float2(1.5f, 0);
                    float e = 0;
                    int i = 0;
                    UNITY_UNROLL
                    for(; i < MAXSTEPS; i++)
                    {
                        e = _MainTex.Sample(sampler_LinearClamp, coord * _MainTex_TexelSize.xy).g;
                        [flatten]
                        if (e < 0.9f)  break;
                        coord += float2(2, 0);
                    }
                    return min(2.0 * (i +  e), 2.0 * MAXSTEPS);
                }

                float SearchYUp(float2 coord)
                {
                    coord -= float2(0, 1.5f);
                    float e = 0;
                    int i = 0;
                    UNITY_UNROLL
                    for(; i < MAXSTEPS; i++)
                    {
                        e = _MainTex.Sample(sampler_LinearClamp, coord * _MainTex_TexelSize.xy).r;
                        [flatten]
                        if (e < 0.9f)  break;
                        coord -= float2(0, 2);
                    }
                    return min(2.0 * (i +  e), 2.0 * MAXSTEPS);
                }

                float SearchYDown(float2 coord)
                {
                    coord += float2(0, 1.5f);
                    float e = 0;
                    int i = 0;
                    UNITY_UNROLL
                    for(; i < MAXSTEPS; i++)
                    {
                        e = _MainTex.Sample(sampler_LinearClamp, coord * _MainTex_TexelSize.xy).r;
                        [flatten]
                        if (e < 0.9f)  break;
                        coord += float2(0, 2);
                    }
                    return min(2.0 * (i +  e), 2.0 * MAXSTEPS);
                }

                //这里是根据双线性采样得到的值，来判断边界的模式
                bool4 ModeOfSingle(float value)
                {
                    bool4 ret = false;
                    if (value > 0.875)
                        ret.yz = bool2(true, true);
                    else if(value > 0.5)
                        ret.z = true;
                    else if(value > 0.125)
                        ret.y = true;
                    return ret;
                }

                //判断两侧的模式
                bool4 ModeOfDouble(float value1, float value2)
                {
                    bool4 ret;
                    ret.xy = ModeOfSingle(value1).yz;
                    ret.zw = ModeOfSingle(value2).yz;
                    return ret;
                }

                //  单侧L型, 另一侧没有, d表示总间隔, m表示像素中心距边缘距离
                //  |____
                // 
                float L_N_Shape(float d, float m)
                {
                    float l = d * 0.5;
                    float s = 0;
                    [flatten]
                    if ( l > (m + 0.5))
                    {
                        // 梯形面积, 宽为1
                        s = (l - m) * 0.5 / l;
                    }
                    else if (l > (m - 0.5))
                    {
                        // 三角形面积, a是宽, b是高
                        float a = l - m + 0.5;
                        // float b = a * 0.5 / l;
                        // float s = a * b * 0.5;
                        float s = a * a * 0.25 * rcp(l);
                    }
                    return s;
                }

                //  双侧L型, 且方向相同
                //  |____|
                // 
                float L_L_S_Shape(float d1, float d2)
                {
                    float d = d1 + d2;
                    float s1 = L_N_Shape(d, d1);
                    float s2 = L_N_Shape(d, d2);
                    return s1 + s2;
                }

                //  双侧L型/或一侧L, 一侧T, 且方向不同, 这里假设左侧向上, 来取正负
                //  |____    |___|    
                //       |       |
                float L_L_D_Shape(float d1, float d2)
                {
                    float d = d1 + d2;
                    float s1 = L_N_Shape(d, d1);
                    float s2 = -L_N_Shape(d, d2);
                    return s1 + s2;
                }

                float Area(float2 d, bool4 left, bool4 right)
                {
                    // result为正, 表示将该像素点颜色扩散至上/左侧; result为负, 表示将上/左侧颜色扩散至该像素
                    float result = 0;
                    [branch]
                    if(!left.y && !left.z)
                    {
                        [branch]
                        if(right.y && !right.z)
                        {
                            result = L_N_Shape(d.y + d.x + 1, d.y + 0.5);
                        }
                        else if (!right.y && right.z)
                        {
                            result = -L_N_Shape(d.y + d.x + 1, d.y + 0.5);
                        }
                    }
                    else if (left.y && !left.z)
                    {
                        [branch]
                        if(right.z)
                        {
                            result = L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                        }
                        else if (!right.y)
                        {
                            result = L_N_Shape(d.y + d.x + 1, d.x + 0.5);
                        }
                        else
                        {
                            result = L_L_S_Shape(d.x + 0.5, d.y + 0.5);
                        }
                    }
                    else if (!left.y && left.z)
                    {
                        [branch]
                        if (right.y)
                        {
                            result = -L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                        }
                        else if (!right.z)
                        {
                            result = -L_N_Shape(d.x + d.y + 1, d.x + 0.5);
                        }
                        else
                        {
                            result = -L_L_S_Shape(d.x + 0.5, d.y + 0.5);
                        }
                    }
                    else
                    {
                        [branch]
                        if(right.y && !right.z)
                        {
                            result = -L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                        }
                        else if (!right.y && right.z)
                        {
                            result = L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                        }
                    }

                #ifdef ROUNDING_FACTOR
                    bool apply = false;
                    if (result > 0)
                    {
                        if(d.x < d.y && left.x)
                        {
                            apply = true;
                        }
                        else if(d.x >= d.y && right.x)
                        {
                            apply = true;
                        }
                    }
                    else if (result < 0)
                    {
                        if(d.x < d.y && left.w)
                        {
                            apply = true;
                        }
                        else if(d.x >= d.y && right.w)
                        {
                            apply = true;
                        }
                    }
                    if (apply)
                    {
                        result = result * ROUNDING_FACTOR;
                    }
                #endif

                    return result;

                }
                
                float4 FragBlend(Varyings i) : SV_Target
                {
                    float2 uv = i.texcoord;
                    float2 ScreenPos = i.texcoord * _MainTex_TexelSize.zw;
                    float2 edge = _MainTex.Sample(sampler_PointClamp, uv).rg;
                    float4 result = 0;
                    bool4 l, r;

                    if (edge.g > 0.1f)
                    {
                        float left = SearchXLeft(ScreenPos);
                        float right = SearchXRight(ScreenPos);
                    #ifdef ROUNDING_FACTOR
                         float left1 = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(-left, -1.25)) * _MainTex_TexelSize.xy, 0).r;
                        float left2 = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(-left, 0.75)) * _MainTex_TexelSize.xy, 0).r;
                        l = ModeOfDouble(left1, left2);
                        float right1 = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(right + 1, -1.25)) * _MainTex_TexelSize.xy, 0).r;
                        float right2 = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(right + 1, 0.75)) * _MainTex_TexelSize.xy, 0).r;
                        r = ModeOfDouble(right1, right2);
                    #else
                       
                        float left_value = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(-left, -0.25)) * _MainTex_TexelSize.xy, 0).r;
                        float right_value = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(right + 1, -0.25)) * _MainTex_TexelSize.xy, 0).r;
                        l = ModeOfSingle(left_value);
                        r = ModeOfSingle(right_value);
                    #endif
                        float value = Area(float2(left, right), l, r);
                        result.xy = float2(-value, value);
                    }

                        if (edge.r > 0.1f)
                        {
                            float up = SearchYUp(ScreenPos);
                            float down = SearchYDown(ScreenPos);

                            bool4 u, d;
                    #ifdef ROUNDING_FACTOR
                            float up1 = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(-1.25, -up)) * _MainTex_TexelSize.xy, 0).g;
                            float up2 = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(0.75, -up)) * _MainTex_TexelSize.xy, 0).g;
                            float down1 = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(-1.25, down + 1)) * _MainTex_TexelSize.xy, 0).g;
                            float down2 = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(0.75, down + 1)) * _MainTex_TexelSize.xy, 0).g;
                            u = ModeOfDouble(up1, up2);
                            d = ModeOfDouble(down1, down2);
                    #else
                            float up_value = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(-0.25, -up)) * _MainTex_TexelSize.xy, 0).g;
                            float down_value = _MainTex.SampleLevel(sampler_LinearClamp, (ScreenPos + float2(-0.25, down + 1)) * _MainTex_TexelSize.xy, 0).g;
                            u = ModeOfSingle(up_value);
                            d = ModeOfSingle(down_value);
                    #endif
                            float value = Area(float2(up, down), u, d);
                            result.zw = float2(-value, value);
                        }
                    
                    return result;
                }
                #pragma vertex Vert
                #pragma fragment FragBlend

            ENDHLSL
        }

        // 进行混合
        Pass
        {
            HLSLPROGRAM

                float4 FragNeighbor(Varyings i) : SV_Target
                {
                    float2 uv = i.texcoord;
                    int2 pixelCoord = uv * _MainTex_TexelSize.zw;
                    float4 TL = _BlendTex.Load(int3(pixelCoord, 0));
                    float R = _BlendTex.Load(int3(pixelCoord + int2(1, 0), 0)).a;
                    float B = _BlendTex.Load(int3(pixelCoord + int2(0, 1), 0)).g;

                    float4 a = float4(TL.r, B, TL.b, R);
                    float4 w = a * a * a;
                    float sum = dot(w, 1.0);

                    [branch]
                    if (sum > 0) {
                        float4 o = a * _MainTex_TexelSize.yyxx;
                        float4 color = 0;

                        color = mad(_MainTex.SampleLevel(sampler_LinearClamp, uv + float2(0.0, -o.r), 0), w.r, color);
                        color = mad(_MainTex.SampleLevel(sampler_LinearClamp, uv + float2( 0.0, o.g), 0), w.g, color);
                        color = mad(_MainTex.SampleLevel(sampler_LinearClamp, uv + float2(-o.b, 0.0), 0), w.b, color);
                        color = mad(_MainTex.SampleLevel(sampler_LinearClamp, uv + float2( o.a, 0.0), 0), w.a, color);
                        return color/sum;
                    } else
                    {
                        return _MainTex.SampleLevel(sampler_LinearClamp, uv, 0);
                    }
                }
                #pragma vertex Vert
                #pragma fragment FragNeighbor

            ENDHLSL
        }
    }
}
