Shader "MyCustom/FurShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalTex("Normal",2D) = "bump"{}
        _FurTex("Mask",2D)="white"{}
        _FurTilling("毛发密度",Range(0.5,2)) = 1
        _ShellCount("Shell层数",Range(0,100)) = 50
        _FurLength("毛发长度",Range(1,50)) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off//关闭深度写入避免半透明排序的问题    
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing//GPU实例化
            #pragma instancing_options assumeuniformscaling //提升性能
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _FurTex;
            float4 _FurTex_ST;
            sampler2D _NormalTex;
            float4 _NormalTex_ST;
            
            float _FurTilling;
            float _FurLength;
            
            StructuredBuffer<float> _ShellIndexBuffer;
            float _ShellCount;
            
            struct appdata//CPU传入的数据
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                uint id : SV_InstanceID;//当前Shader对应的实例物体的id，unity自动传入
            };

            struct v2f//传入到fragment里的数据
            {
                float4 pos : SV_POSITION;
                float2 mainTexUV : TEXCOORD0;
                float2 maskUV : TEXCOORD1;
                float4 maskNormal : TEXCOORD2;//用w分量储存shellFrac
            };
            
            v2f vert (appdata v)
            {
                float shellIndex = _ShellIndexBuffer[v.id];
                float shellFrac = shellIndex/_ShellCount;//id 越大值越大

                v2f o;
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                worldPos += worldPos * worldNormal * (1 + shellFrac) * _FurLength;
                
                o.pos = mul(UNITY_MATRIX_VP,worldPos);
                o.mainTexUV = TRANSFORM_TEX(v.uv, _MainTex);
                o.maskUV = TRANSFORM_TEX(v.uv,_FurTex);
                //o.maskNormal.xyz = v.normal;
                o.maskNormal.w = shellFrac;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.mainTexUV);
                float mask = tex2D(_FurTex,i.maskUV).r;

                //mask = saturate(smoothstep(i.maskNormal.w,1,mask));
                
                col.a = mask;
                return col;
            }
            ENDHLSL
        }
    }
}
