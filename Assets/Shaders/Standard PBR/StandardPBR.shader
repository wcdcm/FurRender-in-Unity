Shader "MyCustom/StandardPBR"
{
    Properties
    {
        BaseMap ("BaseMap", 2D) = "white" {}
        NormalMap("NormalMap",2D) = "bump"{}
        NormalStrength("NormalStrength",Range(1,10)) = 1
        MetalMap("MetalMap",2D) = "white"{}
        Smoothness("Smoothness",Range(0,0.8)) = 0.5
        
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
                float3x3 TBN : TEXCOORD2;//传递TBN矩阵给片元着色器，用于将计算法线的世界空间坐标。float3X3这里会占用 TEXCOORD2, TEXCOORD3, TEXCOORD4三个寄存器
                float3 worldPos : TEXCOORD5;
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

            half NormalStrength;
            half Smoothness;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.mainUV = TRANSFORM_TEX(v.mainUV, BaseMap);
                o.normalUV = TRANSFORM_TEX(v.normalUV,NormalMap);
                float3 N = normalize(TransformObjectToWorldNormal(v.normal));
                float3 T = normalize(TransformObjectToWorldDir(v.tangent.xyz));
                float3 B = cross(N,T) * v.tangent.w;//v.tangent.w 是切线方向的符号，用于计算副切线 B
                o.TBN = float3x3(T,B,N);
                o.worldPos = TransformObjectToWorld(v.vertex).xyz;
                return o;
            }

            
            
            half4 frag (v2f i) : SV_Target
            {
                half4 col;
                half4 baseCol = SAMPLE_TEXTURE2D(BaseMap,sampler_BaseMap,i.mainUV);
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(NormalMap,sampler_NormalMap,i.normalUV));

                // 法线强度调节：放大 XY 分量，然后重建 Z
                normalTS.xy *= NormalStrength;
                normalTS = normalize(normalTS);
                
                half3 normalWS = normalize(mul(normalTS,i.TBN));//世界空间法线
                
                //Light
                Light mainLight = GetMainLight();//Light Source
                half3 L = normalize(mainLight.direction);//Light Dir
                half3 N = normalWS;//World Space Normal
                half3 V = normalize(GetCameraPositionWS() - i.worldPos);//view Dir
                half3 H = normalize(V + L);//半角向量
                
                //光照系数
                float NdotL = saturate(max(0.1,dot(L,N)));
                float NdotV = saturate(dot(N,V));//表面法线和视角方向的夹角余弦,用于判断观察方向与表面是否正对
                float NdotH = saturate(dot(N,H));//
                float VdotH = saturate(dot(V,H));
                
                
                //Diffuse
                half3 diffuse = baseCol * NdotL * mainLight.color * mainLight.distanceAttenuation;

                //Metallic,金属表面几乎没有漫反射，非金属才保留 baseCol,金属部分反射率很高所以几乎没有颜色
                half metallic = SAMPLE_TEXTURE2D(MetalMap,sampler_MetalMap,i.mainUV).r;
                diffuse = lerp(diffuse,0.01,metallic);

                //smoothness
                half smoothness = Smoothness;
                half roughness = 1 - smoothness;

                // ========== 镜面反射 (Cook-Torrance 简化版) ==========
                half3 F0 = lerp(0.04, baseCol, metallic); // 基础反射率
                half3 F = F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0); // Fresnel-Schlick

                float alpha = roughness * roughness;
                float alpha2 = alpha * alpha;

                // D: Trowbridge-Reitz GGX
                float denom = (NdotH * NdotH) * (alpha2 - 1.0) + 1.0;
                float D = alpha2 / (PI * denom * denom);

                // G: Smith's Schlick-GGX
                float k = (alpha + 1.0) * (alpha + 1.0) / 8.0;
                float Gv = NdotV / (NdotV * (1.0 - k) + k);
                float Gl = NdotL / (NdotL * (1.0 - k) + k);
                float G = Gv * Gl;

                half3 specular = (D * G * F) / (4.0 * NdotL * NdotV + 0.001);
                
                col.rgb = diffuse + specular * mainLight.color * NdotL;
                return col;
            }
            ENDHLSL
        }
    }
}
