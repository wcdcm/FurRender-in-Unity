Shader "MyCustom/FurShader"
{
    Properties
    {
         //毛发噪声纹理
        _FurTex("Fur Texture", 2D) = "white" {}
        //毛发根部颜色
        [HDR]_RootColor("RootColor",Color)=(0,0,0,1)
        //毛发末端颜色
        [HDR]_FurColor("FurColor",Color)=(1,1,1,1)
         //凹凸纹理
        _BumpTex("Normal Map", 2D) = "bump" {}
        //凹凸强度
        _BumpIntensity("Bump Intensity",Range(0,2))=1
        //毛发长度
        _FurLength("Fur Length", Float) = 0.2
        //壳层总数
        _ShellCount("Shell Count", Float) = 16
        //外发光颜色
        [HDR]_FresnelColor("Fresnel Color", Color) = (1,1,1,1)
        //菲涅尔强度
        _FresnelPower("Fresnel Power", Float) = 5
        //噪声剔除阈值
        _FurAlphaPow("Fur AlphaPow", Range(0,6)) = 1
    }
 
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        LOD 200
        ZWrite Off
        Cull Back
        Blend SrcAlpha OneMinusSrcAlpha
 
        Pass
        {
            Name "FurPass"
            Tags { "LightMode" = "UniversalForward" }
 
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
           
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            TEXTURE2D(_FurTex); SAMPLER(sampler_FurTex);
            float4 _FurTex_ST;
            TEXTURE2D(_BumpTex); SAMPLER(sampler_BumpTex);
            float4 _BumpTex_ST;
            float _FurLength;
            float _ShellCount;
            float _WindStrength;
            float4 _FresnelColor;
            float _FresnelPower;
            float _FurAlphaPow;
            float4 _RootColor;
            float4 _FurColor;
 
            StructuredBuffer<float> _ShellIndexBuffer;
           
 
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                uint id: SV_InstanceID;
            };
 
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float shellIndex : TEXCOORD3;
                
            };
    
 
            v2f vert(appdata v)
            {
                float shellIndex = _ShellIndexBuffer[v.id];
                float shellFrac = shellIndex / _ShellCount;
                v2f o;
                
                float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
 
                float windOffset = sin(worldPos.x * 5 + _Time.y * 2 + shellIndex) * _WindStrength;
                worldPos += worldNormal * (_FurLength * shellFrac + windOffset);
 
                o.pos = TransformWorldToHClip(worldPos);
                o.uv = TRANSFORM_TEX(v.uv, _FurTex);
                o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
                o.worldNormal = worldNormal;
                o.shellIndex = shellIndex;
                return o;
            }
 
            half4 frag(v2f i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_FurTex, sampler_FurTex, i.uv);
                float shellFrac = i.shellIndex / _ShellCount;
                float mask = SAMPLE_TEXTURE2D(_FurTex, sampler_FurTex, i.uv).r;
 
                float alpha= saturate(mask - pow(shellFrac,_FurAlphaPow));
 
                float3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpTex, sampler_BumpTex, i.uv));
                float3 normalWS = normalize(i.worldNormal + bump * 0.5);
                float fresnel = pow(1.0 - saturate(dot(i.viewDir, normalWS)), _FresnelPower);
 
                //AO
                col*=lerp(_RootColor,_FurColor,shellFrac);
                col.a = alpha;
                col.rgb += _FresnelColor.rgb * fresnel * alpha;
                return col;
          
            }
            ENDHLSL
        }
    }
}
