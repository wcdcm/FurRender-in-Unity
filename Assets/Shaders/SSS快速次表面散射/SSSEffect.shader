Shader "Custom/FastSSS"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        _SSSWidth("SSS Blur Width", Range(0, 5)) = 1.0
        _SSSStrength("SSS Strength", Range(0, 2)) = 1.0
        _SpecularStrength("Specular Strength", Range(0, 2)) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            Name "SSSForward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
            };

            sampler2D _MainTex;
            sampler2D _NormalMap;

            float _SSSWidth;
            float _SSSStrength;
            float _SpecularStrength;

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.normalWS   = TransformObjectToWorldNormal(v.normalOS);
                o.uv = v.uv;
                o.viewDirWS = GetWorldSpaceViewDir(v.positionOS);
                return o;
            }

            // ================================
            // 漫反射（Direct Diffuse）
            // ================================
            float3 ComputeDiffuse(float3 normal, float3 lightDir, float3 albedo)
            {
                float NdotL = saturate(dot(normal, lightDir));
                return albedo * NdotL;
            }

            // ================================
            // 镜面反射（Specular，不模糊）
            // ================================
            float3 ComputeSpecular(float3 normal, float3 viewDir, float3 lightDir)
            {
                float3 H = normalize(viewDir + lightDir);
                float NdotH = saturate(dot(normal, H));
                return pow(NdotH, 32) * _SpecularStrength; // GGX可替换
            }

            // ================================
            // 次表面散射模糊核（近似三层皮肤）
            // ================================
            float3 ApplySSSBlur(float2 uv, sampler2D tex)
            {
                // 核权重（可调）
                float kernel[5] = {0.25, 0.2, 0.15, 0.1, 0.05};

                float3 sum = tex2D(tex, uv).rgb * kernel[0];
                float2 offset = _SSSWidth / _ScreenParams.xy;

                // 只写一维模糊，实际用 separable filter
                for (int i=1; i<5; i++)
                {
                    sum += tex2D(tex, uv + float2(offset.x*i, 0)).rgb * kernel[i];
                    sum += tex2D(tex, uv - float2(offset.x*i, 0)).rgb * kernel[i];
                }

                return sum * _SSSStrength;
            }

            // ================================
            // 主片元函数
            // ================================
            float4 frag(Varyings i) : SV_Target
            {
                float3 albedo = tex2D(_MainTex, i.uv).rgb;
                float3 normal = normalize(i.normalWS);
                float3 viewDir = normalize(i.viewDirWS);

                // 获取主光
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);

                // 基础光照
                float3 diffuse = ComputeDiffuse(normal, lightDir, albedo);
                float3 specular = ComputeSpecular(normal, viewDir, lightDir);

                // SSS 模糊近似
                float3 sss = ApplySSSBlur(i.uv, _MainTex);

                // 混合结果
                float3 color = diffuse * (1 - _SSSStrength) + sss + specular;

                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
