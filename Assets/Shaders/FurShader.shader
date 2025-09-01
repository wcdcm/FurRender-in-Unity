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
        fresnelPower("边缘光强度",Range(0,10)) = 1
        [HDR]edgeColor("边缘光颜色",Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags
        {
            //将Transparent队列改为AlphaTest避免透明度穿插的问题，并且可以节省性能
            "RenderType"="AlphaTest"
            "Queue"="AlphaTest"
        }
        LOD 100

        Pass
        {
            Name "FurPass"
            Tags{"LightMode"="UniversalForward"}
            //Blend SrcAlpha OneMinusSrcAlpha
            //ZWrite Off//关闭深度写入避免半透明排序的问题    
            Blend Off
            ZWrite On
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing//GPU实例化
            #pragma instancing_options assumeuniformscaling //提升性能
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _FurTex;
            float4 _FurTex_ST;
            sampler2D _NormalTex;
            float4 _NormalTex_ST;
            
            float _FurTilling;
            float _FurLength;
            float fresnelPower;
            float3 edgeColor;
            
            StructuredBuffer<float> _ShellIndexBuffer;
            float _ShellCount;
            
            struct appdata//CPU传入的数据
            {
                float4 vertex : POSITION;
                float3 vertexNormal : NORMAL;
                float2 uv : TEXCOORD0;
                uint id : SV_InstanceID;//当前Shader对应的实例物体的id，unity自动传入
            };

            struct v2f//从vert传入到fragment里的数据
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD3;//储存片元的世界空间坐标便于光照计算
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
                float3 worldNormal = TransformObjectToWorldNormal(v.vertexNormal);
                worldPos += normalize(worldNormal) * shellFrac * _FurLength;
                o.worldPos = worldPos;
                
                o.pos = mul(UNITY_MATRIX_VP,float4(worldPos,1));
                o.mainTexUV = TRANSFORM_TEX(v.uv, _MainTex);
                o.maskUV = TRANSFORM_TEX(v.uv,_FurTex);
                o.maskNormal.xyz = worldNormal;
                o.maskNormal.w = shellFrac;//用w分量储存shellFrac
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.mainTexUV);
                float mask = tex2D(_FurTex,i.maskUV).r;
                //边缘光计算
                float3 N = normalize(i.maskNormal.xyz);//获取片元的世界法线方向
                float3 V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);//获取片元到摄像机的方向向量
                float fresnel = pow(1 - saturate(max(0,dot(N,V))),fresnelPower);
                col.rgb = lerp(col.rgb,edgeColor,fresnel);

                //Lambert光照计算
                Light mainLight = GetMainLight();
                float3 L = normalize(mainLight.direction.xyz);//获取光源方向
                float NdotL = max(0.1,dot(N,L));
                col.rgb *= NdotL * mainLight.color * mainLight.distanceAttenuation;//mainLight.color 包含了光源强度
                
                //剔除计算
                float shellFrac = i.maskNormal.w;
                mask = smoothstep(shellFrac, shellFrac + 0.05, mask);
                col.a = mask;
                clip(col.a - 0.5);//丢弃Alpha小于0.5的部分
                return col;
            }
            ENDHLSL
        }
    }
}
