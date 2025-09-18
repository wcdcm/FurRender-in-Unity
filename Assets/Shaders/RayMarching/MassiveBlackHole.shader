Shader "Custom/MassiveBlackHole"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varying
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 posWS : TEXCOORD1;
            };
            
            TEXTURE2D(MainTex);
            SAMPLER(sampler_MainTex);
            float4 MainTex_ST;
            
            Varying vert (Attributes v)
            {
                Varying o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, MainTex);
                return o;
            }

            //float2 intersectSphere
            
            float4 frag (Varying i) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(MainTex,sampler_MainTex,i.uv);
                float3 rayDir = normalize(i.posWS - _WorldSpaceCameraPos);
                float3 rayOrigin = _WorldSpaceCameraPos;
                return float4(0.5,0,0,1);
            }
            ENDHLSL
        }
    }
}
