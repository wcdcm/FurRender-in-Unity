Shader "Unlit/Parallax"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _DetailTex ("Detail", 2D) = "white" {}
        _NormalTex ("Normal", 2D) = "bump" {}
        _HeightTex ("Height", 2D) = "white" {}
        _ParallaxIntensity("ParallaxIntensity",Range(0.01 ,1)) = 0.1
        _BumpScale("Bump Scale", Range(0,2)) = 0.2
        [Toggle(JITTER)]_Jitter("Jitter",Float) = 0
        [Toggle(Parallax)]_Parallax("Parallax",Float) = 0
        _BaseColor("BaseColor", Color) = (1,1,1,0)
        
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
            #pragma shader_feature _ JITTER
            #pragma shader_feature _ Parallax

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            struct Varinfgs
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 tangent : TANGENT;
                float3 normal : NORMAL; 
            };
            struct Output
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 viewDir : TEXCOORD1; //切线空间的视线方向
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float3 normalWS : TEXCOORD4;
            };

            TEXTURE2D(_MainTex);
            TEXTURE2D(_DetailTex);
            TEXTURE2D(_NormalTex);
            TEXTURE2D(_HeightTex);
            SAMPLER(sampler_MainTex);

            float4 _MainTex_ST;
            float4 _DetailTex_ST;

            half _ParallaxIntensity;
            half _BumpScale;
            half4 _BaseColor;

            Output vert (Varinfgs v)
            {
                Output o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = vertexInput.positionCS;
                //[世界空间视线]转[切线空间视线]
                float3x3 objectToTangent = float3x3(
                    v.tangent.xyz, 
                    cross(v.normal, v.tangent.xyz) * v.tangent.w,
                    v.normal);
                float3 positionWS = vertexInput.positionWS;
                float3 cameraPositionWS = _WorldSpaceCameraPos;
                //世界空间视线转模型空间
                float3 viewDirWS = TransformWorldToObjectDir(positionWS - cameraPositionWS);
                //模型空间转切线空间
                o.viewDir = mul(objectToTangent, viewDirWS);
                
                //法线贴图解析数据
                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal.xyz,v.tangent);
                o.normalWS = normalInputs.normalWS;
                o.bitangentWS = normalInputs.bitangentWS;
                o.tangentWS  = normalInputs.tangentWS;

                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
                return o;
            }
            //高度图采样
            half GetParallaxHeight(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_HeightTex, sampler_MainTex, uv).r;
            }
            //抖动的随机噪声
            float RandomNoise(float2 uv) //这里使用 SV_POSITION 作为uv输入
            {   
                uv += 1 * float2(47.0, 17.0) * 0.695;
                const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
                return frac(magic.z * frac(dot(uv, magic.xy)));
            }
            //视差步进
            float2 ParallaxRaymarching(float4 positionCS, float2 uv, float3 viewDir) 
            {
                float maxLayers = 20;
                float noise = RandomNoise(positionCS.xy);
                #ifdef JITTER
                    maxLayers = maxLayers * 0.5 + maxLayers * noise;
                #endif

                float stepSize = 1 / maxLayers;
                float layerHeight = stepSize;
                float2 uvDelta  = _ParallaxIntensity * viewDir.xy / viewDir.z  * stepSize;

                float2 uvOffset = 0;
                float2 currentUV = uv;
                float stepHeight  = 1.0;

                float heightMap = GetParallaxHeight(currentUV);
                for (int i = 1; i < maxLayers && stepHeight > heightMap; i++) //当i小于最大循环次数且当前高度值大于当前步进循环内采样的高度值时，循环继续
                {
                    uvOffset -= uvDelta;
                    stepHeight -= layerHeight;
                    heightMap = GetParallaxHeight(currentUV + uvOffset);
                }
                return uvOffset;
            }
            half4 frag (Output i) : SV_Target
            {
                float2 uvOffset = 0;

                #ifdef Parallax
                    uvOffset = ParallaxRaymarching(i.positionCS, i.uv.xy, normalize(i.viewDir));
                #endif

                float2 currentUV = i.uv.xy + uvOffset;

                //简单的 NdotL 光照模型
                Light light = GetMainLight();
                float4 normalTex = SAMPLE_TEXTURE2D(_NormalTex, sampler_MainTex, currentUV);
                float3 normalTS = UnpackNormalScale(normalTex,_BumpScale);
                float3 normalWS = TransformTangentToWorld(normalTS, real3x3(i.tangentWS, i.bitangentWS, i.normalWS));
                float power = saturate(dot(light.direction,normalWS)); 

                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, currentUV);
                half4 details = SAMPLE_TEXTURE2D(_DetailTex, sampler_MainTex, i.uv.zw + uvOffset);

                return albedo * power * _BaseColor ;//+ details;
            }
            ENDHLSL
        }
    }
}