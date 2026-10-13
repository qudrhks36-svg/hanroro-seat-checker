// 물고기 그림자 (GDD 8번 3단계 [확정]): 물 위에 얹는 어두운 반투명 모양. 그림 파일 없이 정점 색의 알파로 가장자리를 부드럽게 한다.
Shader "FishingGame/FlatShadow"
{
    Properties { _Alpha ("Alpha", Range(0, 1)) = 0.28 }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _Alpha;
            CBUFFER_END
            struct Attributes { float4 positionOS : POSITION; float4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float4 color : COLOR; float fog : TEXCOORD0; };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.color = i.color; o.fog = ComputeFogFactor(o.positionCS.z);
                return o;
            }
            half4 frag(Varyings i) : SV_Target
            {
                float3 col = MixFog(float3(0.02, 0.10, 0.18), i.fog);
                return half4(col, i.color.a * _Alpha);
            }
            ENDHLSL
        }
    }
}
