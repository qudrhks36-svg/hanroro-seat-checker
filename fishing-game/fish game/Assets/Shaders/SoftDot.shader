// 반딧불 점 (GDD 8번 3단계 [확정]): 가운데가 밝고 가장자리로 부드럽게 사라지는 빛 점. 그림 파일 없이 셰이더가 그린다. 더해서 그려져(Additive) 어두울수록 잘 보인다.
Shader "FishingGame/SoftDot"
{
    Properties { _Intensity ("Intensity", Float) = 2.2 }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha One
        ZWrite Off
        Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _Intensity;
            CBUFFER_END
            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; float4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; float4 color : COLOR; };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv = i.uv; o.color = i.color;
                return o;
            }
            half4 frag(Varyings i) : SV_Target
            {
                float d = length(i.uv - 0.5) * 2.0;
                float a = saturate(1.0 - d); a = a * a;
                float core = saturate(1.0 - d * 2.5);
                return half4(i.color.rgb * _Intensity + core * 1.5, saturate(a * 1.6) * i.color.a);
            }
            ENDHLSL
        }
    }
}
