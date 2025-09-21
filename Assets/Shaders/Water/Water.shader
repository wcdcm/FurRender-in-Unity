Shader "Custom/Water"
{
    Properties
    {
        _DepthMin("DepthMin",Range(0,1)) = 0
        _DepthMax("DepthMax",Range(0,1)) = 1
        _WaterColorDeep("深水区颜色",Color) = (0,0.2,0.4,1)
        _WaterColorShallow("浅水区颜色",Color) = (1,0.9,0.9,1)
        
        [Toggle]_UseFoam("使用泡沫",int) = 0
        _FoamShape("泡沫形状",2D) = "white"{}
        _FoamRange("泡沫范围",Range(0.01,5)) = 1
        _FoamSmoothness("泡沫平滑度",Range(0.01,1)) = 1
        _FoamStrength("泡沫亮度",Range(0.01,1)) = 1
        _FoamDetails("泡沫细节",2D)="white"{}
        
        [Toggle]_UseRefract("使用折射",int) = 0
        _RefractTex("水面折射贴图",2D)="white"{}
        _RefractFactor("水面折射度",Float)=0.5
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
            Name "Unlit"
            Tags
            {
                "LightMode"="UniversalForward"
            }
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 detailUV : TEXCOORD2;
                
            };

            struct v2f
            {
                float4 posCS : SV_POSITION;//投影（裁剪）空间顶点坐标
                float3 posVS : TEXCOORD1;//视图空间顶点坐标
                float2 uv : TEXCOORD0;
                float2 detailUV : TEXCOORD2;
            };
            
            sampler2D _CameraDepthTexture;
            float _DepthMin;
            float _DepthMax;
            float4 _WaterColorDeep;
            float4 _WaterColorShallow;

            //泡沫形状采样器
            float _UseFoam;
            sampler2D _FoamShape;
            float4 _FoamShape_ST;

            float _FoamRange;
            float _FoamSmoothness;
            float _FoamStrength;

            //泡沫细节
            sampler2D _FoamDetails;
            float4 _FoamDetails_ST;

            //折射
            sampler2D _RefractTex;float4 _RefractTex_ST;
            float _RefractFactor;
            
            v2f vert (appdata v)
            {
                v2f o;
                //注意：顶点通过矩阵变换变换到投影（裁剪）空间之前都是三个分量，但是变换到投影空间时返回一个float4的向量，因为投影空间的w分量存储的是透视系数。
                //投影空间坐标除以透视系数得到NDC空间坐标
                o.posCS = TransformObjectToHClip(v.vertex);
                float3 posWS = TransformObjectToWorld(v.vertex);
                o.posVS = TransformWorldToView(posWS);
                o.uv = TRANSFORM_TEX(v.uv, _FoamShape) + _Time.x;//计算泡沫贴图的UV并对它们进行偏移
                o.detailUV = TRANSFORM_TEX(v.detailUV,_FoamDetails) + _Time.x * 0.8;//计算泡沫细节贴图的UV并对它们进行偏移
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float2 screenUV = i.posCS.xy/_ScreenParams.xy;

                // float2 refractionUV = tex2D(_RefractTex,i.uv).xy;
                // float2 originalUV = screenUV;
                //
                // screenUV = lerp(originalUV,refractionUV,_RefractFactor);
                
                //如果unity默认使用的是D3D的图形API，则会默认启用深度缓冲区的Reverse-Z的方式，所以片元深度值越小片元越白（接近于1），深度值越大片元越黑（接近于0）
                //Reverse-Z主要是为了解决远端物体深度精度不足的问题
                //采样不透明物体的深度值，该深度值是在NDC空间进行计算的
                float _depth = tex2D(_CameraDepthTexture,screenUV.xy);

                //将NDC空间的值转换到视图空间，便于深度判断
                _depth = LinearEyeDepth(_depth,_ZBufferParams);
                
                //获取水面深度 = 视图空间中物体的深度值 - 水面各片元在视图空间下的深度值
                //因为unity的视图空间采用的是右手坐标系，所以z轴方向都是负值，所以_depth和i.posVS.z都是负值，如果要相减就把它们变为正值后再减
                //深度为正，说明不透明物体在水面下;深度为负，说明不透明物体在水面上。

                half waterDepth = saturate(abs(_depth) - abs(i.posVS.z));//计算得到水的深度
                half4 waterCol = lerp(_WaterColorShallow,_WaterColorDeep,waterDepth);
                float foam = 0;
                if (_UseFoam)
                {
                    foam = tex2D(_FoamShape,i.uv);//采样泡沫贴图获取泡沫形状
                    float foamDetails = tex2D(_FoamDetails,i.detailUV);//采样细节贴图
                    foam *= foamDetails;//叠加细节
                    float foamRange = _FoamRange * waterDepth;//计算出泡沫范围
                    foam = pow(foam,_FoamSmoothness);
                    foam = step(foamRange,foam);//根据泡沫抠出泡沫的
                    foam *= _FoamStrength;
                }
                waterCol.a = 0.7;
                return foam + waterCol;
            }
            ENDHLSL
        }
    }
}
