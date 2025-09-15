Shader "Custom/SSDisturbance"
{
    Properties
    {
        DisturbTex ("_DisturbTex", 2D) = "white" {}
        DisturbStrength("DisturbStrength",range(0,1)) = 1
        FlowSpeed("FlowSpeed",Float) = 1
    }
    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "RenderPipeline"="UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Name "Disturb Pass"
            Tags {"LightMode"="UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 posOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 posCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;//顶点在屏幕空间中的位置
            };

            TEXTURE2D(DisturbTex);
            SAMPLER(sampler_DisturbTex);    
            float4 DisturbTex_ST;
            float DisturbStrength;
            float FlowSpeed;

            //URP管线下，抓屏只抓一次，但内置管线下会一个Shader抓一次
            TEXTURE2D(_CameraOpaqueTexture);//urp管线下内置的，用于抓取不透明场景的纹理
            SAMPLER(sampler_CameraOpaqueTexture);

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.posCS = TransformObjectToHClip(v.posOS);
                o.uv = TRANSFORM_TEX(v.uv, DisturbTex);
                o.screenPos = ComputeScreenPos(o.posCS);
                return o;
            }

            float4 frag (Varyings i) : SV_Target
            {
                float2 screenUV = (i.screenPos.xy / i.screenPos.w);
                float2 disturbUV = i.uv + float2(0, FlowSpeed) * _Time.x;//让扰动贴图流动
                float2 disturb = SAMPLE_TEXTURE2D(DisturbTex, sampler_DisturbTex, disturbUV).rg * 2 - 1;
                float2 disturbedUV = screenUV + disturb * DisturbStrength * 0.01; // 控制强度
                float4 col = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,disturbedUV);

                return col;
            }
            ENDHLSL
        }
    }
}