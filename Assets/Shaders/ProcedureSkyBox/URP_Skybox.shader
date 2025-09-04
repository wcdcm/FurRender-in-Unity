Shader "Custom/URP_TianKongHe"
{
    Properties
    {
        hdrMap ("HDR", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Background"
            "IgnoreProjector"="True"
            "Queue"="Background"
        }
        Pass
        {
            Tags
            {
                //"LightMode"="Skybox"//这条不能写，否则会出现上一帧不清除的情况
            }
            ZWrite Off
            Cull Front
            Fog {Mode Off}
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(hdrMap);
            SAMPLER(sampler_hdrMap);
            
            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 dirWS : TEXCOORD1;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.dirWS = TransformObjectToWorld(IN.positionOS.xyz);//表示在世界空间下，从物体中心到任意顶点的向量，经过当前片元射向天空的射线
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float3 dir = normalize(IN.dirWS);
                float2 uv;
                uv.x = atan2(dir.x,dir.z)/(2 * PI) + 0.5;//atan2 ∈ [-π,π]
                uv.y = asin(dir.y)/PI + 0.5;//asin ∈ [-π/2,π/2]

                //防止接缝异常
                uv.x = frac(uv.x);
                //uv.x = saturate(frac(uv.x) * (1 - 1e-5));
                uv.y = saturate(uv.y);
                float4 hdrCol = SAMPLE_TEXTURE2D(hdrMap,sampler_hdrMap,uv);
                float4 finalCol = hdrCol;
                
                return finalCol;
            }
            ENDHLSL
        }
    }
}