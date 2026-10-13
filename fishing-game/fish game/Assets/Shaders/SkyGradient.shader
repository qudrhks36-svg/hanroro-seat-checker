// 그라데이션 하늘 (GDD 8번 [확정] 1단계): 위쪽 색 → 지평선(안개) 색, 해 둘레의 빛무리와 해, 밤엔 별과 달.
// 색은 시간대마다 TimeOfDay가 전역 값(_SkyTop/_SkyGlowColor/_SunDir/_SkyGlow/_Stars)으로 넣어 준다. 지평선·아래쪽은 안개 색(unity_FogColor)과 똑같아서 바다 끝과 매끈하게 이어진다.
Shader "FishingGame/SkyGradient"
{
    SubShader
    {
        Tags { "RenderType"="Background" "Queue"="Background" "PreviewType"="Skybox" "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 _SkyTop, _SkyGlowColor, _SunDir;
            float _SkyGlow, _Stars;

            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; float3 dir : TEXCOORD0; };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.dir = i.positionOS.xyz;
                return o;
            }

            float hash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

            half4 frag(Varyings i) : SV_Target
            {
                float3 d = normalize(i.dir);
                float3 horizon = unity_FogColor.rgb;
                float up = saturate(d.y);
                float3 col = lerp(horizon, _SkyTop.rgb, pow(up, 0.55));            // 위로 갈수록 짙은 하늘색
                col = lerp(col, horizon, saturate(-d.y * 6.0));                      // 지평선 아래는 안개 색

                float3 sun = normalize(_SunDir.xyz);
                float sd = saturate(dot(d, sun));
                col += _SkyGlowColor.rgb * (pow(sd, 6.0) * 0.30 + pow(sd, 60.0) * 0.35) * _SkyGlow;   // 해 둘레 빛무리
                col = lerp(col, _SkyGlowColor.rgb, smoothstep(0.9990, 0.9996, sd) * saturate(_SkyGlow));   // 해

                // 밤: 별과 달
                float2 uv = float2(atan2(d.z, d.x) * 52.0, d.y * 90.0);
                float2 cell = floor(uv);
                float star = step(0.985, hash(cell)) * smoothstep(0.42, 0.0, length(frac(uv) - 0.5 + (hash(cell + 7.0) - 0.5) * 0.4));
                col += star * _Stars * smoothstep(0.02, 0.25, d.y);
                float moon = smoothstep(0.9988, 0.9993, saturate(dot(d, -sun)));
                col = lerp(col, float3(0.95, 0.96, 0.85), moon * _Stars);
                return half4(col, 1.0);
            }
            ENDHLSL
        }
    }
}
