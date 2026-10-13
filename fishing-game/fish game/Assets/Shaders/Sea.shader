// 바다 (GDD 8번 [확정] 1단계): 깊이에 따른 색, 물결무늬, 해안 거품, 햇빛 반짝임. 섬 중심은 월드 (0,0), 해안은 반지름 20.
// 색은 시간대마다 TimeOfDay가 전역 값(_SeaShallow/_SeaDeep/_SeaFoam/_SeaGlint)으로 바꿔 준다.
Shader "FishingGame/Sea"
{
    Properties
    {
        _ShoreRadius ("Shore Radius", Float) = 20
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _ShoreRadius;
            CBUFFER_END
            float4 _SeaShallow, _SeaDeep, _SeaFoam;
            float _SeaGlint;

            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; float3 positionWS : TEXCOORD0; float fogFactor : TEXCOORD1; };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.fogFactor = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            float hash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
            float vnoise(float2 p)
            {
                float2 i = floor(p), f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(hash(i), hash(i + float2(1, 0)), f.x), lerp(hash(i + float2(0, 1)), hash(i + float2(1, 1)), f.x), f.y);
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 xz = i.positionWS.xz;
                float t = _Time.y;
                float sd = length(xz) - _ShoreRadius;                       // 해안에서 얼마나 먼가

                float depth = pow(saturate(sd / 22.0), 0.65);
                float3 col = lerp(_SeaShallow.rgb, _SeaDeep.rgb, depth);

                // 부드러운 물결무늬 (움직이는 두 겹의 잔물결)
                float n = vnoise(xz * 0.30 + float2(t * 0.10, t * 0.07)) * 0.6 + vnoise(xz * 0.85 - float2(t * 0.16, t * 0.05)) * 0.4;
                col += (n - 0.5) * 0.10;
                col = lerp(col, _SeaShallow.rgb * 1.15, smoothstep(0.62, 0.78, n) * 0.35);

                // 해안 거품: 밀려오는 물결 선 + 모래 가까이의 띠
                float near = 1.0 - saturate(sd / 7.0);
                float wave = sin(sd * 1.5 - t * 0.9 + n * 2.0);
                float lines = smoothstep(0.88, 1.0, wave) * near;
                float band = smoothstep(2.4 + 0.6 * sin(t * 0.8 + n * 4.0), 0.0, sd);
                float foam = saturate(lines * 0.9 + band * (0.55 + 0.45 * vnoise(xz * 1.6 + t * 0.2)));
                col = lerp(col, _SeaFoam.rgb, foam);

                // 햇빛 반짝임
                float sp = vnoise(xz * 2.6 + float2(t * 0.6, -t * 0.4));
                col += _SeaFoam.rgb * pow(saturate(sp), 14.0) * _SeaGlint * (0.4 + depth * 0.6);

                col = MixFog(col, i.fogFactor);
                return half4(col, 1.0);
            }
            ENDHLSL
        }
    }
}
