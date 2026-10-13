// 물결 고리 (GDD 9번 [확정] 낚시 연출): 가운데가 비고 가장자리가 부드러운 하얀 고리. 그림 파일 없이 셰이더가 그린다. 더해서 그려진다(Additive).
Shader "FishingGame/Ring"
{
    Properties { _Intensity ("Intensity", Float) = 1.4 }
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
                float ring = smoothstep(0.62, 0.86, d) * smoothstep(1.0, 0.88, d);
                return half4(i.color.rgb * _Intensity, ring * i.color.a);
            }
            ENDHLSL
        }
    }
}
