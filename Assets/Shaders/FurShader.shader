Shader "MyCustom/FurShader_AnisoSpec"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalTex("Normal",2D) = "bump"{}
        _FurTex("Mask",2D)="white"{}
        _ShellCount("Shell层数",Range(0,100)) = 50
        _FurLength("毛发长度",Range(1,50)) = 1
        fresnelPower("边缘光强度",Range(0,10)) = 1
        [HDR]edgeColor("边缘光颜色",Color) = (1,1,1,1)
        specularIntensity("高光强度",Float) = 1
        specularRange("高光范围",Float) = 8
        _AnisoStrength("各向异性强度",Range(0,2)) = 0.8
        _AnisoPower("各向异性尖锐度",Range(1,32)) = 8
    }
    SubShader
    {
        Tags
        {
            "RenderType"="AlphaTest"
            "Queue"="AlphaTest"
        }
        LOD 200

        Pass
        {
            Name "FurPass"
            Tags{"LightMode"="UniversalForward"}
            Blend Off
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _FurTex;
            float4 _FurTex_ST;
            sampler2D _NormalTex;
            float4 _NormalTex_ST;

            float _FurLength;
            float fresnelPower;
            float3 edgeColor;
            float specularIntensity;
            float specularRange;
            float _AnisoStrength;
            float _AnisoPower;

            StructuredBuffer<float> _ShellIndexBuffer;
            float _ShellCount;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 vertexNormal : NORMAL;
                float2 uv : TEXCOORD0;
                uint id : SV_InstanceID;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD3;
                float2 mainTexUV : TEXCOORD0;
                float2 maskUV : TEXCOORD1;
                float4 maskNormal : TEXCOORD2; // xyz = normal, w = shellFrac
            };

            v2f vert (appdata v)
            {
                v2f o;
                float shellIndex = _ShellIndexBuffer[v.id];
                float shellFrac = shellIndex/_ShellCount;

                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(v.vertexNormal);
                worldPos += normalize(worldNormal) * shellFrac * _FurLength;
                o.worldPos = worldPos;

                o.pos = mul(UNITY_MATRIX_VP,float4(worldPos,1));
                o.mainTexUV = TRANSFORM_TEX(v.uv, _MainTex);
                o.maskUV = TRANSFORM_TEX(v.uv,_FurTex);
                o.maskNormal.xyz = worldNormal;
                o.maskNormal.w = shellFrac;
                return o;
            }

            // safe normalize to avoid NaNs
            float3 safeNormalize(float3 v)
            {
                float l = length(v);
                return l > 1e-6 ? v / l : float3(0,0,1);
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 albedo = tex2D(_MainTex, i.mainTexUV);
                float mask = tex2D(_FurTex, i.maskUV).r;

                // 片元法线方向
                float3 N = normalize(i.maskNormal.xyz);

                //视线方向
                float3 V = safeNormalize(_WorldSpaceCameraPos.xyz - i.worldPos);

                // 菲涅尔计算
                float fresnel = pow(1 - saturate(dot(N,V)), fresnelPower);
                float3 baseCol = lerp(albedo.rgb, edgeColor, fresnel);

                // 主光源方向
                Light mainLight = GetMainLight();
                float3 L = normalize(mainLight.direction.xyz);
                if (all(L == 0)) L = normalize(float3(0,1,0));

                //baseColor计算
                float NdotL = saturate(max(0.3,dot(N,L)));
                float3 diffuse = baseCol * NdotL * mainLight.color * mainLight.distanceAttenuation;

                // Construct a stable tangent frame for anisotropy: pick a consistent "up" and build T,B
                float3 up = abs(N.y) < 0.99 ? float3(0,1,0) : float3(1,0,0);
                float3 T = safeNormalize(cross(up, N));//计算切线
                float3 B = cross(N, T);//计算副法线

                // 半角向量（用于计算Specular和各向异性）
                float3 H = safeNormalize(L + V);

                // Blinn-Phong specular模型
                float NdotH = saturate(dot(N,H));
                float specBase = pow(NdotH, max(1.0,specularRange)) * specularIntensity;

                // Anisotropy: measure alignment of H with tangent directions
                float HT = dot(H, T);
                float HB = dot(H, B);
                // use absolute dot so direction of H matters only in magnitude
                float lon = pow(abs(HT), _AnisoPower); // longitudinal lobe
                float lat = pow(abs(HB), _AnisoPower); // latitudinal lobe

                // Build anisotropy modifier: when lon >> lat, boost specular along T direction
                float anisoFactor = lerp(1.0, lon, saturate(_AnisoStrength));
                // Optional: subtract lat contribution to create directional variation
                anisoFactor = anisoFactor * (1.0 - 0.5 * saturate(lat * saturate(_AnisoStrength)));

                float3 specular = specBase * anisoFactor * baseCol * mainLight.color;

                // Combine
                float3 color = diffuse + specular;

                // Alpha / masking
                float shellFrac = i.maskNormal.w;
                mask = smoothstep(shellFrac, shellFrac + 0.05, mask);
                float alpha = mask;
                clip(alpha - 0.5);

                float4 outCol = float4(color, alpha);
                return outCol;
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
