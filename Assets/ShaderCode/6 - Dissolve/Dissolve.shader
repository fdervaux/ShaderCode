Shader "Example/Dissolve"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _NoiseScale("Noise Scale", Float) = 8
        _DissolveThreshold("Dissolve Threshold", Range(0,1)) = 0.5
        _EdgeWidth("Edge Width", Range(0,0.5)) = 0.1
        [HDR] _EdgeColor("Edge Color", Color) = (1, 0, 0, 1)
        _NoiseSpeed("Noise Speed", Float) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderType"="TransparentCutout" "Queue"="AlphaTest" "RenderPipeline"="UniversalRenderPipeline"
        }

        Pass
        {
            Cull off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _NoiseScale;
                float _DissolveThreshold;
                float _EdgeWidth;
                float4 _EdgeColor;
                float _NoiseSpeed;
            CBUFFER_END

            inline float unity_noise_randomValue(float3 p)
            {
                return frac(sin(dot(p, float3(12.9898, 78.233, 45.164))) * 43758.5453);
            }

            inline float unity_noise_randomValue(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            inline float unity_noise_interpolate(float a, float b, float t)
            {
                return (1.0 - t) * a + (t * b);
            }

            inline float unity_valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);

                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = unity_noise_randomValue(c0);
                float r1 = unity_noise_randomValue(c1);
                float r2 = unity_noise_randomValue(c2);
                float r3 = unity_noise_randomValue(c3);

                float bottomOfGrid = unity_noise_interpolate(r0, r1, f.x);
                float topOfGrid = unity_noise_interpolate(r2, r3, f.x);
                float t = unity_noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            inline float unity_valueNoise3(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);
                f = f * f * (3.0 - 2.0 * f); // smoothstep fade

                // cube corners
                float3 c000 = i + float3(0.0, 0.0, 0.0);
                float3 c100 = i + float3(1.0, 0.0, 0.0);
                float3 c010 = i + float3(0.0, 1.0, 0.0);
                float3 c110 = i + float3(1.0, 1.0, 0.0);
                float3 c001 = i + float3(0.0, 0.0, 1.0);
                float3 c101 = i + float3(1.0, 0.0, 1.0);
                float3 c011 = i + float3(0.0, 1.0, 1.0);
                float3 c111 = i + float3(1.0, 1.0, 1.0);

                float r000 = unity_noise_randomValue(c000);
                float r100 = unity_noise_randomValue(c100);
                float r010 = unity_noise_randomValue(c010);
                float r110 = unity_noise_randomValue(c110);
                float r001 = unity_noise_randomValue(c001);
                float r101 = unity_noise_randomValue(c101);
                float r011 = unity_noise_randomValue(c011);
                float r111 = unity_noise_randomValue(c111);

                // trilinear interpolation
                float bx00 = unity_noise_interpolate(r000, r100, f.x);
                float bx10 = unity_noise_interpolate(r010, r110, f.x);
                float bx01 = unity_noise_interpolate(r001, r101, f.x);
                float bx11 = unity_noise_interpolate(r011, r111, f.x);

                float bxy0 = unity_noise_interpolate(bx00, bx10, f.y);
                float bxy1 = unity_noise_interpolate(bx01, bx11, f.y);

                float t = unity_noise_interpolate(bxy0, bxy1, f.z);
                return t;
            }

            void Unity_SimpleNoise_float(float2 UV, float Scale, out float Out)
            {
                float t = 0.0;

                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += unity_valueNoise(float2(UV.x * Scale / freq, UV.y * Scale / freq)) * amp;

                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += unity_valueNoise(float2(UV.x * Scale / freq, UV.y * Scale / freq)) * amp;

                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += unity_valueNoise(float2(UV.x * Scale / freq, UV.y * Scale / freq)) * amp;
                Out = t;
            }

            void Unity_SimpleNoise3_float(float3 P, float Scale, out float Out)
            {
                float t = 0.0;

                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3 - 0));
                t += unity_valueNoise3(P * Scale / freq) * amp;

                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3 - 1));
                t += unity_valueNoise3(P * Scale / freq) * amp;

                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3 - 2));
                t += unity_valueNoise3(P * Scale / freq) * amp;
                Out = t;
            }
            
            void Dither(float4 In, float4 ScreenPosition, out float4 Out)
            {
                float2 uv = ScreenPosition.xy * _ScreenParams.xy;
                float DITHER_THRESHOLDS[16] =
                {
                    1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
                    13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
                    4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
                    16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
                };
                uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;
                Out = In - DITHER_THRESHOLDS[index];
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.worldPos = mul(unity_ObjectToWorld, IN.positionOS).xyz;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 baseCol = _BaseColor * baseTex;

                float n;

                // time-based offset pour animer le bruit
                float t = _Time.y; // time en secondes (Unity)
                float3 timeOffset = float3(t * _NoiseSpeed, t * _NoiseSpeed * 0.37, t * _NoiseSpeed * 0.73);

                //Unity_SimpleNoise_float(IN.uv, max(0.0001, _NoiseScale), n);
                Unity_SimpleNoise3_float(IN.worldPos + timeOffset, max(0.0001, _NoiseScale), n);

                
                // Appliquer le dithering pour lisser le alpha clipping
                float4 ditheredAlpha;
                float edgeDitherMask = smoothstep(_DissolveThreshold - 0.1, _DissolveThreshold, n);
                
                
                Dither(float4(edgeDitherMask, 0, 0, 0), IN.positionHCS, ditheredAlpha);
                //return ditheredAlpha;
               
                //return ditheredAlpha;
                //clip((1-edgeDitherMask.x) - n);
                
                clip((1-ditheredAlpha.x *2) - 0.5);

                float edgeMask = smoothstep(_DissolveThreshold - _EdgeWidth, _DissolveThreshold, n);

                half4 finalCol = lerp(baseCol, _EdgeColor, edgeMask);
                finalCol.a = baseCol.a;

                return finalCol;
            }
            ENDHLSL
        }
    }
}