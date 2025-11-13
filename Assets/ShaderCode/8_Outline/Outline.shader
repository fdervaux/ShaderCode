Shader "Outline"
{

    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _SecondOutlineColor ("Second Outline Color", Color) = (1,1,1,1)
        _OutlineDepthThreshold ("Depth Threshold", Range(0,1)) = 0.01
        _OutlineNormalThreshold ("Normal Threshold", Range(0,1)) = 0.2
        _OutlineKernelSize ("Kernel Size", Int) = 3
        _OutlineWidth ("Outline Width", Float) = 1
        _OutlineEllipseWidth ("Outline Ellipse Width", Range(0,1)) = 1.0
        _OutlineEllipseAngle ("Outline Ellipse Angle (rad)", Range(0,6.28)) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        ZWrite Off Cull Off
        Pass
        {
            Name "OutlinePass"

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #pragma target 3.0
            #pragma vertex Vert
            #pragma fragment frag

            float _OutlineDepthThreshold;
            float _OutlineNormalThreshold;
            int _OutlineKernelSize;
            float _OutlineWidth;
            float _OutlineEllipseWidth;
            float _OutlineEllipseAngle;

            inline float sample_linear_depth(float2 uv)
            {
                float d = SampleSceneDepth(uv);
                return Linear01Depth(d, _ZBufferParams);
            }

            inline float3 sample_normal(float2 uv)
            {
                float3 normals = SampleSceneNormals(uv);
                //remap from [-1,1] to [0,1]
                normals = normals * 0.5f + 0.5f;
                return normals;
            }

            inline float2 get_texel_size()
            {
                return 1.0f / _ScreenParams.xy;
            }

            inline float sample_depth_offset(float2 uv, int ox, int oy, float distance = 1.0f)
            {
                float2 texel = get_texel_size();
                return sample_linear_depth(uv + float2(ox, oy) * texel * lerp(1, _OutlineWidth, distance));
            }

            inline float3 sample_normal_offset(float2 uv, int ox, int oy, float distance = 1.0f)
            {
                float2 texel = get_texel_size();
                return sample_normal(uv + float2(ox, oy) * texel * lerp(1, _OutlineWidth, distance));
            }

            inline float ellipseDistance(int x, int y, int half_kernel_size, float w, float h, float ca, float sa)
            {
                if (half_kernel_size == 0) return false;
                float u = (float)x / (float)half_kernel_size;
                float v = (float)y / (float)half_kernel_size;

                // rotation
                float xr = u * ca - v * sa;
                float yr = u * sa + v * ca;

                // évite division par zéro
                w = max(w, 1e-5);
                h = max(h, 1e-5);

                float val = (xr / w) * (xr / w) + (yr / h) * (yr / h);
                return val;
            }

            // Convolution with kernel NxN where tous les éléments != centre = -1
            // et centre = N*N - 1. Retourne un masque [0,1].
            inline float compute_outline_mask_kernel(float2 uv, int kernel_size)
            {
                const int MAX_HALF = 5; // support up to kernel_size = 11
                int half_kernel_size = kernel_size / 2;
                float sum_weights = 0.0f;

                float accum_depth = 0.0f;
                float3 accum_normal = float3(0.0f, 0.0f, 0.0f);

                float cd = sample_depth_offset(uv, 0, 0);
                float3 cn = sample_normal_offset(uv, 0, 0);

                float distance = saturate(1 - cd);

                for (int y = -MAX_HALF; y <= MAX_HALF; ++y)
                {
                    if (abs(y) > half_kernel_size) continue;
                    for (int x = -MAX_HALF; x <= MAX_HALF; ++x)
                    {
                        if (abs(x) > half_kernel_size) continue;
                        if (x == 0 && y == 0) continue; // on traite le centre à part

                        float ellipseDist = ellipseDistance(x, y, half_kernel_size,
                                                _OutlineEllipseWidth,
                                                1,
                                                cos(_OutlineEllipseAngle),
                                                sin(_OutlineEllipseAngle));

                        if (ellipseDist > 1.0f)
                            continue;

                        // weight décroissant avec le carré de la distance
                        float w = saturate(1.0f - ellipseDist);
                        w = pow(w, 6);

                        float d = sample_depth_offset(uv, x, y, distance);
                        float3 n = sample_normal_offset(uv, x, y, distance);

                        accum_depth -= w * d;
                        accum_normal -= w * n;
                        sum_weights += w;
                    }
                }

                accum_depth += cd * sum_weights;
                accum_normal += cn * sum_weights;

                float depth_response = abs(accum_depth / sum_weights);
                float normal_response = length(accum_normal / sum_weights);

                float depth_edge = smoothstep(_OutlineDepthThreshold * 0.5, _OutlineDepthThreshold, depth_response);
                float normal_edge = smoothstep(_OutlineNormalThreshold * 0.5, _OutlineNormalThreshold, normal_response);

                return saturate(max(depth_edge, normal_edge));
            }


            // Out frag function takes as input a struct that contains the screen space coordinate we are going to use to sample our texture. It also writes to SV_Target0, this has to match the index set in the UseTextureFragment(sourceTexture, 0, …) we defined in our render pass script.   
            float4 frag(Varyings input) : SV_Target0
            {
                // this is needed so we account XR platform differences in how they handle texture arrays
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // sample the texture using the SAMPLE_TEXTURE2D_X_LOD
                float2 uv = input.texcoord.xy;

                //outline logic here
                float mask = compute_outline_mask_kernel(uv, _OutlineKernelSize);

                //return mask;
                return mask;
            }
            ENDHLSL
        }

        Pass
        {
            Name "OutlineComposite" // pass 1 : lit le mask, blur 3x3 et compose
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #pragma target 3.0
            #pragma vertex Vert
            #pragma fragment FragComposite

            float4 _OutlineColor;
            float4 _SecondOutlineColor;
            float _OutlineDepthThreshold;

            TEXTURE2D(_OutlineMaskTex);

            inline float sample_linear_depth(float2 uv)
            {
                float d = SampleSceneDepth(uv);
                return Linear01Depth(d, _ZBufferParams);
            }

            inline float4 apply_outline(float2 uv, float4 baseColor, float mask, float depth)
            {
                float factor = uv.y * 2 - 0.5f;
                float4 outline_color = lerp(_OutlineColor, _SecondOutlineColor, factor);
                float3 result = lerp(baseColor.rgb, outline_color.rgb, mask * outline_color.a * (1.0f - depth));
                return float4(result, baseColor.a);
            }

            float4 FragComposite(Varyings input) : SV_Target0
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 uv = input.texcoord.xy;
                float2 texel = 1.0f / _ScreenParams.xy;

                float4 color = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, uv, _BlitMipLevel);

                // profondeur centrale pour pondération bilatérale
                float centerDepth = sample_linear_depth(uv);
                float depthFade = max(_OutlineDepthThreshold * 4.0f, 1e-6f);

                // offsets pour bilinear fetch trick (échantillons bilinéaires couvrant plus d'area)
                float2 offs[4] = {
                    float2(1.5, 0.0),
                    float2(-1.5, 0.0),
                    float2(0.0, 1.5),
                    float2(0.0, -1.5)
                };

                // poids de base (centre plus 4 taps)
                float centerMask = SAMPLE_TEXTURE2D_X_LOD(_OutlineMaskTex, sampler_LinearRepeat, uv, _BlitMipLevel).r;
                float accum = centerMask * 4.0;
                float wsum = 4.0;

                for (int i = 0; i < 4; ++i)
                {
                    float2 offUV = uv + offs[i] * texel;
                    float sampleMask = SAMPLE_TEXTURE2D_X_LOD(_OutlineMaskTex, sampler_LinearRepeat, offUV,
             _BlitMipLevel).r;
                    float sampleDepth = sample_linear_depth(offUV);
                    float depthWeight = saturate(1.0 - abs(sampleDepth - centerDepth) / depthFade);
                    float w = 1.0 * depthWeight;
                    accum += sampleMask * w;
                    wsum += w;
                }

                float blurred = (wsum > 0.0) ? (accum / wsum) : 0.0;

                float cd = centerDepth;
                if (cd >= 1.0f) return color;

                return apply_outline(uv, color, saturate(blurred), cd);
            }

            /*float4 FragComposite(Varyings input) : SV_Target0
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 uv = input.texcoord.xy;
                float2 texel = 1.0f / _ScreenParams.xy;

                float4 color = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, uv, _BlitMipLevel);

                // kernel gaussien 3x3 (séparable mais calculé 2D ici pour simplicité)
                float k[3] = {1.0f, 2.0f, 1.0f};
                float kernelSum = 0.0f;
                float accum = 0.0f;

                // profondeur centrale
                float centerDepth = sample_linear_depth(uv);

                // facteur de robustesse contre bleeding : on tolère plusieurs fois le seuil de détection
                float depthFade = max(_OutlineDepthThreshold * 4.0f, 1e-6f);

                for (int oy = -1; oy <= 1; ++oy)
                {
                    for (int ox = -1; ox <= 1; ++ox)
                    {
                        int ky = oy + 1;
                        int kx = ox + 1;
                        float kw = k[kx] * k[ky]; // produit 1/2/4 etc
                        float2 off = uv + float2(ox, oy) * texel;

                        // sample mask
                        float sampleMask = SAMPLE_TEXTURE2D_X_LOD(_OutlineMaskTex, sampler_LinearRepeat, off,
                                                            _BlitMipLevel).r;

                        // depth-aware weight (simple bilateral term)
                        float sampleDepth = sample_linear_depth(off);
                        float depthDiff = abs(sampleDepth - centerDepth);
                        // poids réduit si grande différence de profondeur
                        float depthWeight = saturate(1.0f - depthDiff / depthFade);

                        // accumule pondéré
                        float w = kw * depthWeight;
                        accum += sampleMask * w;
                        kernelSum += w;
                    }
                }

                float blurred = (kernelSum > 0.0f) ? accum / kernelSum : 0.0f;

                float cd = centerDepth;
                if (cd >= 1.0f) return color;

                return apply_outline(uv, color, saturate(blurred), cd);
            }*/
            ENDHLSL
        }
    }

}