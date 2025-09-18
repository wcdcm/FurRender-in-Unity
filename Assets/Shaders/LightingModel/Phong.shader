Shader "Custom/MyPhong"
{
    Properties
    {
        MainTex ("Texture", 2D) = "white" {}
        MainTint("Color",Color) = (0,0,0,0)
        Smoothness("Smoothness",Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            struct Attributes
            {
                float4 posOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varying
            {
                float4 posCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            };
            
            TEXTURE2D(MainTex);
            SAMPLER(sampler_MainTex);
            float4 MainTex_ST;
            float4 MainTint;
            float Smoothness;
            
            Varying vert (Attributes v)
            {
                Varying o;
                o.posCS = TransformObjectToHClip(v.posOS);
                o.uv = TRANSFORM_TEX(v.uv, MainTex);
                o.normalWS = normalize(TransformObjectToWorldNormal(v.normalOS));
                o.posWS = TransformObjectToWorld(v.posOS);
                return o;
            }

            float4 frag (Varying i) : SV_Target
            {
                float4 albedo =SAMPLE_TEXTURE2D(MainTex,sampler_MainTex,i.uv);
                float3 L = GetMainLight().direction;
                float3 N = normalize(i.normalWS);
                float NdotL = max(0.1,dot(L,N));
                float3 baseCol = albedo * NdotL * GetMainLight().distanceAttenuation * GetMainLight().color * MainTint;
                float3 V = normalize(_WorldSpaceCameraPos - i.posWS);
                float3 R = normalize(reflect(-L,N));//计算反射光
                float3 specular = pow(saturate(dot(R,V)),Smoothness * 128);
                float3 col = baseCol + specular;
                return float4(specular,1);
            }
            ENDHLSL
        }
    }
}
