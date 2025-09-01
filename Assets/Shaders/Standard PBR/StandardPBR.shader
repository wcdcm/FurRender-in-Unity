Shader "MyCustom/StandardPBR"
{
    Properties
    {
        BaseMap ("BaseMap", 2D) = "white" {}
        NormalMap("NormalMap",2D) = "bump"{}
        MetalMap("MetalMap",2D) = "white"{}
        Smoothness("Smoothness",Float) = 0.5
        
        OcclusionMap("OcclusionMap",2D) = "white"{}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }
        LOD 100

        Pass
        {
            Tags {"LightMode"="UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 mainUV : TEXCOORD0;
                float2 normalUV : TEXCOORD1;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 mainUV : TEXCOORD0;
                float2 normalUV : TEXCOORD1;
                float3x3 TBN : TEXCOORD2;//传递TBN矩阵给片元着色器，用于将
            };
            
            TEXTURE2D(BaseMap);
            SAMPLER(sampler_BaseMap);
            float4 BaseMap_ST;//control tilling and offset

            TEXTURE2D(NormalMap);
            SAMPLER(sampler_NormalMap);
            float4 NormalMap_ST;

            TEXTURE2D(MetalMap);
            SAMPLER(sampler_MetalMap);
            float4 MetalMap_ST;
            
            v2f vert (appdata v)
            {
                v2f o;
                //o.pos = TransformObjectToHClip(v.vertex);
                o.pos = mul(UNITY_MATRIX_MVP,v.vertex);
                o.mainUV = TRANSFORM_TEX(v.mainUV, BaseMap);
                o.normalUV = TRANSFORM_TEX(v.normalUV,NormalMap);
                float3 N = normalize(TransformObjectToWorldNormal(v.normal));
                float3 T = normalize(TransformObjectToWorldDir(v.tangent.xyz));
                float3 B = cross(N,T) * v.tangent.w;//v.tangent.w 是切线方向的符号，用于计算副切线 B
                o.TBN = float3x3(T,B,N);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 col;
                half4 baseCol = SAMPLE_TEXTURE2D(BaseMap,sampler_BaseMap,i.mainUV);
                half3 normalTS = SAMPLE_TEXTURE2D(NormalMap,sampler_NormalMap,i.normalUV).xyz * 2 - 1;//SAMPLE_TEXTURE2D 返回 [0,1]，需要 *2-1 转换成 [-1,1]。
                
                //Light
                Light mainLight = GetMainLight();
                
                //Light Dir
                half3 L = normalize(mainLight.direction);
                
                //Normal Dir in World Space
                half3 normalWS = normalize(mul(normalTS,i.TBN));

                float NdotL = max(0.3,dot(L,normalWS));

                //Diffuse
                float3 diffuse = baseCol * NdotL * mainLight.color * mainLight.distanceAttenuation;
                col.rgb = diffuse;
                return col;
            }
            ENDHLSL
        }
    }
}
