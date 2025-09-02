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
            float3 FresnelSchlik(float costheta,float3 F0)
            {
                return F0 + (1 - F0) * pow(1-costheta,5);
            }
            //微表面分布函数D(h)
            float DistributionGGX(float NdotH,float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float denom = (NdotH * NdotH) * (a2 - 1.0) + 1.0;
                return a2 / (PI * denom * denom + 1e-6);
            }
            //几何遮蔽函数G（N，L，V)
            float GeometrySchlickGGX(float NdotV, float roughness)
            {
                float r = roughness + 1.0;
                float k = (r * r) / 8.0;  // UE4 style
                return NdotV / (NdotV * (1.0 - k) + k);
            }
            float GeometrySmith(float NdotV, float NdotL, float roughness)
            {
                return GeometrySchlickGGX(NdotV, roughness) * GeometrySchlickGGX(NdotL, roughness);
            }

            //直射光
            float3 BRDF_Direct(float3 N,float3 V,float3 L,Light light,float3 albedo,float metallic,float roughness)
            {
                float3 H = normalize(dot(L,V));

                float NdotL = saturate(max(0.1,dot(L,N)));//用于计算漫反射
                float NdotV = normalize(dot(N,V));//表面法线和视角方向的夹角余弦,用于判断观察方向与表面是否正对
                float NdotH = normalize(dot(N,H));//高光分布（NDF）核心参数
                float HdotV = normalize(dot(H,V));//Fresnel反射关键参数

                //基础反射率F0
                float F0 = lerp(float3(0.04,0.04,0.04),albedo,metallic);

                //Cook-Terrance模型
                float F = FresnelSchlik(HdotV,F0);//计算菲涅尔
                float D = DistributionGGX(NdotH,roughness);//计算微表面法线分布函数
                float G = GeometrySmith(NdotV,NdotL,roughness);//计算几何遮蔽函数

                float3 specular = (D * F * G)/(4 * NdotV * NdotL + 1e-6);

                // kD = 漫反射能量 (金属越高漫反射越低)
                float3 kS = F;
                float3 kD = (1.0 - kS) * (1.0 - metallic);
                float3 diffuse = kD * albedo / PI;
                
                diffuse = albedo * NdotL * light.color * light.distanceAttenuation;
                diffuse = lerp(albedo,0.01,metallic);
                    
                return diffuse + specular * light.color * light.distanceAttenuation;
            }
            
            half4 frag (v2f i) : SV_Target
            {
                half4 col;
                half4 albedo = SAMPLE_TEXTURE2D(BaseMap,sampler_BaseMap,i.mainUV);
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
                float NdotL = saturate(max(0.1,dot(L,N)));//用于计算漫反射
                float NdotV = saturate(dot(N,V));//表面法线和视角方向的夹角余弦,用于判断观察方向与表面是否正对
                float NdotH = saturate(dot(N,H));//高光分布（NDF）核心参数
                float VdotH = saturate(dot(V,H));//Fresnel反射关键参数
                
                
                //Diffuse
                half3 diffuse = albedo * NdotL * mainLight.color * mainLight.distanceAttenuation;

                //Metallic,金属表面几乎没有漫反射，非金属才保留 baseCol,金属部分反射率很高所以几乎没有颜色
                half metallic = SAMPLE_TEXTURE2D(MetalMap,sampler_MetalMap,i.mainUV).r;
                diffuse = lerp(diffuse,0.01,metallic);

                //smoothness
                half smoothness = Smoothness;
                half roughness = 1 - smoothness;

                // ========== 镜面反射 (Cook-Torrance 简化版) ==========

                //1.计算GXX(NDF) 微表面分布函数D（h）
                float a = roughness * roughness;//a通常表示粗糙度参数
                float down = PI * pow((pow(NdotH,2) * (a * a - 1) + 1),2);
                float D = (a * a)/down;

                //2.计算菲涅尔项 F（V,h）
                float F0 = lerp(0.04,albedo,metallic);//反射率，非金属（dielectric）的平均反射率，大约 4%。金属度 = 1 → 完全金属，F0 = baseCol（镜面反射就是材质颜色）
                float F = F0 + (1.0 - F0) * pow(1 - VdotH,5);

                //3.计算几何遮蔽函数G（L，V，h）近似
                float k = (a + 1)*(a + 1)/8.0;
                float Gnv = NdotV/(NdotV * (1 - k) + k);
                float Gnl = NdotL/(NdotL * (1 - k) + k);
                float G = Gnv * Gnl;
                half3 specular = (D * F * G) / (4 * NdotL * NdotV + 0.001);//+0.001防止除0异常
                
                col.rgb = diffuse + specular * mainLight.color * NdotL;
                return col;
            }
            ENDHLSL
        }
    }
}
