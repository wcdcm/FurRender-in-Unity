Shader "Custom/Water"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DepthMin("DepthMin",Range(0,1)) = 0
        _DepthMax("DepthMax",Range(0,1)) = 1
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
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 posCS : SV_POSITION;//投影（裁剪）空间顶点坐标
                float3 posVS : TEXCOORD1;//视图空间顶点坐标
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _CameraDepthTexture;
            float _DepthMin;
            float _DepthMax;
            
            v2f vert (appdata v)
            {
                v2f o;
                //注意：顶点通过矩阵变换变换到投影（裁剪）空间之前都是三个分量，但是变换到投影空间时返回一个float4的向量，因为投影空间的w分量存储的是透视系数。
                //投影空间坐标除以透视系数得到NDC空间坐标
                o.posCS = TransformObjectToHClip(v.vertex);
                float3 posWS = TransformObjectToWorld(v.vertex);
                o.posVS = TransformWorldToView(posWS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float2 screenUV = i.posCS.xy/_ScreenParams.xy;
                
                //如果unity默认使用的是D3D的图形API，则会默认启用深度缓冲区的Reverse-Z的方式，所以片元深度值越小片元越白（接近于1），深度值越大片元越黑（接近于0）
                //Reverse-Z主要是为了解决远端物体深度精度不足的问题
                float _depth = tex2D(_CameraDepthTexture,screenUV.xy);//采样不透明物体的深度值，该深度值是在NDC空间进行计算的

                // //不管是OpenGL还是D3D的API，都可以用Linear01Depth将非线性的深度值转换到0-1的线性范围内，并且不会做深度反转。屏蔽了不同图形API的差异性
                // _depth = Linear01Depth(_depth,_ZBufferParams);
                //
                // //使用SmoothStep函数将深度值从接近1的一个小范围拉伸到0-1，使用SmoothStep将中间值的区分度拉高
                // _depth = smoothstep(_DepthMin,_DepthMax,(_depth - _DepthMin)/(_DepthMax - _DepthMin));

                _depth = LinearEyeDepth(_depth,_ZBufferParams);//将NDC空间的值转换到视图空间，便于深度判断
                
                //因为视图空间，远裁剪面和近裁剪面的距离过大，比如说0.3-1000.所以需要除以一个值，将它们缩放到0-1之间
                //_depth/=20;

                //对depth的数值进行重映射
                //_depth = smoothstep(_DepthMin,_DepthMax,(_depth - _DepthMin)/(_DepthMax - _DepthMin));


                //获取水面深度 = 视图空间中物体的深度值 - 水面各片元在视图空间下的深度值
                //因为unity的视图空间采用的是右手坐标系，所以z轴方向都是负值，所以_depth和i.posVS.z都是负值，
                float waterDepth = _depth + i.posVS.z;
                
                return waterDepth;
            }
            ENDHLSL
        }
    }
}
