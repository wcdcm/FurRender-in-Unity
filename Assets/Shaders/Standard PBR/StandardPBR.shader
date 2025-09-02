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

            //===============BRDF工具函数===============
            //菲涅尔项 F(V，h）
            float3 FresnelSchlik(float HdotV,float3 F0)
            {
                return F0 + (1 - F0) * pow(1-HdotV,5);
            }
            //适用于金属的微表面分布函数D(h)
            float DistributionGGX(float NdotH,float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float denom = (NdotH * NdotH) * (a2 - 1.0) + 1.0;
                return a2 / (PI * denom * denom + 0.001);
            }
            //几何遮蔽函数G（N，L，V)
            float GeometrySchlickGGX(float NdotX, float roughness)
            {
                float a = roughness * roughness;
                float k = ((a + 1.0) * (a + 1.0)) / 8.0;  
                return NdotX / (NdotX * (1.0 - k) + k);
            }
            float GeometrySmith(float NdotV, float NdotL, float roughness)
            {
                return GeometrySchlickGGX(NdotV, roughness) * GeometrySchlickGGX(NdotL, roughness);
            }

            //=============直射光============================
            float3 BRDF_Direct(float3 N,float3 V,float3 L,Light mainLight,float3 albedo,float metallic,float roughness)
            {
                float3 H = normalize(L + V);

                float NdotL = saturate(max(0.1,dot(L,N)));//用于计算漫反射
                float NdotV = saturate(dot(N,V));//表面法线和视角方向的夹角余弦,用于判断观察方向与表面是否正对
                float NdotH = saturate(dot(N,H));//高光分布（NDF）核心参数
                float HdotV = saturate(dot(H,V));//Fresnel反射关键参数

                //基础反射率F0
                float3 F0 = lerp(float3(0.04,0.04,0.04),albedo,metallic);

                //Cook-Terrance模型(基于物理的微表面模型)
                float F = FresnelSchlik(HdotV,F0);//计算菲涅尔
                float D = DistributionGGX(NdotH,roughness);//计算微表面法线分布函数
                float G = GeometrySmith(NdotV,NdotL,roughness);//计算几何遮蔽函数

                half3 specular = (D * F * G)/(4 * NdotV * NdotL + 0.001);

                // kD = 漫反射能量 (能量守恒)(金属越高漫反射越低)
                float3 kS = F;
                float3 kD = (1.0 - kS) * (1.0 - metallic);
                float3 diffuse = kD * albedo / PI;

                //兰伯特模型计算diffuse的写法：
                //diffuse = albedo * NdotL * mainLight.color * mainLight.distanceAttenuation;
                //diffuse = lerp(diffuse,0.01,metallic);
                //return diffuse + specular * mainLight.color * mainLight.distanceAttenuation;
                return (diffuse + specular) * mainLight.color * mainLight.distanceAttenuation * NdotL;
            }

            //==============环境光=====================
            float3 BRDF_IBL()
            {
                
            }
            
            half4 frag (v2f i) : SV_Target
            {
                half4 col;
                half4 albedo = SAMPLE_TEXTURE2D(BaseMap,sampler_BaseMap,i.mainUV);
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(NormalMap,sampler_NormalMap,i.normalUV));
                half metallic = SAMPLE_TEXTURE2D(MetalMap,sampler_MetalMap,i.mainUV).r;
                // 法线强度调节：放大 XY 分量，然后重建 Z
                normalTS.xy *= NormalStrength;
                normalTS = normalize(normalTS);
                half3 normalWS = normalize(mul(normalTS,i.TBN));//世界空间法线
                
                //Light
                Light mainLight = GetMainLight();//Light Source
                half3 L = normalize(mainLight.direction);//Light Dir
                half3 N = normalWS;//World Space Normal
                half3 V = normalize(GetCameraPositionWS() - i.worldPos);//view Dir
                
                //roughness
                half smoothness = Smoothness;
                half roughness = 1 - smoothness;
                
                float3 directLighting = BRDF_Direct(N,V,L,mainLight,albedo,metallic,roughness);
                
                col.rgb = directLighting;
               
                return col;
            }
            ENDHLSL
        }
    }
}
