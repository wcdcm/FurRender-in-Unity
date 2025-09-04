Shader "Custom/ParallelMapping"
{
    Properties
    {
        MainTex ("Texture", 2D) = "white" {}
        NormalMap("NormalMap",2D) = "bump"{}
        HeightMap("HeightMap",2D) = "white"{}
        Smoothness("Smoothness",Float) = 0.5
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;//对象空间法线
                float4 tangent : TANGENT;//对象空间切线
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3x3 TBN : TEXCOORD1;//占TEXCOORD1，TEXCOORD2，TEXCOORD3
            };

            TEXTURE2D(MainTex);
            SAMPLER(sampler_MainTex);
            float4 MainTex_ST;

            TEXTURE2D(NormalMap);
            SAMPLER(sampler_NormalMap);
            float4 NormalMap_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, MainTex);
                float3 N = TransformObjectToWorldNormal(v.normal.xyz,true);
                float3 T = TransformObjectToWorldDir(v.tangent,true);
                float3 B = cross(N,T) * v.tangent.w;
                o.TBN = float3x3(T,B,N);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(MainTex,sampler_MainTex,i.uv);
                float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(NormalMap,sampler_NormalMap,i.uv));//切线空间法线
                float3 normalWS = normalize(mul(normalTS,i.TBN));//将切线空间转换为世界空间
                float3 N = normalWS;
                float3 L = GetMainLight().direction;
                float NdotL = max(0.1,(dot(N,L)));
                float3 diffuse = GetMainLight().color * GetMainLight().distanceAttenuation * NdotL;
                col.rgb *= diffuse;
                return col;
            }
            ENDHLSL
        }
    }
}
