Shader "MyCustom/ClipShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MaskTex("Mask",2D)="white"{}
        _Threshold("阈值",Range(0,1)) = 0.5
        _FurTilling("毛发密度",Range(0.5,2)) = 1
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
            sampler2D _MaskTex;
            float4 _MaskTex_ST;
            float _Threshold;
            float _FurTilling;
            
            //定义每个实例的可变属性
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float,threshold)
            UNITY_INSTANCING_BUFFER_END(Props)
            
            struct appdata
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID//用于让unity确定当前是哪一个实例ID
                float4 vertex : POSITION;
                float2 mainTexUV : TEXCOORD0;
                float2 maskUV : TEXCOORD1;
            };

            struct v2f
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID//用于让unity确定当前是哪一个实例ID
                float4 vertex : SV_POSITION;
                float2 mainTexUV : TEXCOORD0;
                float2 maskUV : TEXCOORD1;
            };
            
            v2f vert (appdata v)
            {
                v2f o;

                //设置实例ID并传递
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(o,v);
                
                o.vertex = mul(UNITY_MATRIX_MVP,v.vertex);
                o.mainTexUV = TRANSFORM_TEX(v.mainTexUV, _MainTex);
                o.maskUV = TRANSFORM_TEX(v.maskUV,_MaskTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.mainTexUV);
                float mask = tex2D(_MaskTex,i.maskUV).r;
                
                _Threshold = UNITY_ACCESS_INSTANCED_PROP(Props,threshold);

                mask = smoothstep(_Threshold,1,mask);
                col.a = mask;
                return col;
            }
            ENDHLSL
        }
    }
}
