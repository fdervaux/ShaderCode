

void MainLight_float(out float3 Direction, out float3 Color, out float DistanceAtten){
    #ifdef SHADERGRAPH_PREVIEW
    Direction = normalize(float3(1,1,-0.4));
    Color = float4(1,1,1,1);
    DistanceAtten = 1;
    #else
    Light mainLight = GetMainLight();
    Direction = mainLight.direction;
    Color = mainLight.color;
    DistanceAtten = mainLight.distanceAttenuation;
    #endif
}
void MainLight_half(out half3 Direction, out half3 Color, out half DistanceAtten){
    #ifdef SHADERGRAPH_PREVIEW
    Direction = normalize(float3(1,1,-0.4));
    Color = float4(1,1,1,1);
    DistanceAtten = 1;
    #else
    Light mainLight = GetMainLight();
    Direction = mainLight.direction;
    Color = mainLight.color;
    DistanceAtten = mainLight.distanceAttenuation;
    #endif
}

void MainLightShadows_float(float3 WorldPos, half4 Shadowmask, out float ShadowAtten){
    #ifdef SHADERGRAPH_PREVIEW
    ShadowAtten = 1;
    #else
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
    float4 shadowCoord = ComputeScreenPos(TransformWorldToHClip(WorldPos));
    #else
    float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
    #endif
    ShadowAtten = MainLightShadow(shadowCoord, WorldPos, Shadowmask, _MainLightOcclusionProbes);
    #endif
}

void MainLightShadows_float(float3 WorldPos, out float ShadowAtten){
    MainLightShadows_float(WorldPos, half4(1,1,1,1), ShadowAtten);
}

void MainLightShadows_half(float3 WorldPos, half4 Shadowmask, out half ShadowAtten){
    #ifdef SHADERGRAPH_PREVIEW
    ShadowAtten = 1;
    #else
    #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
    float4 shadowCoord = ComputeScreenPos(TransformWorldToHClip(WorldPos));
    #else
    float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
    #endif
    ShadowAtten = MainLightShadow(shadowCoord, WorldPos, Shadowmask, _MainLightOcclusionProbes);
    #endif
}

void MainLightShadows_half(float3 WorldPos, out half ShadowAtten){
    MainLightShadows_half(WorldPos, half4(1,1,1,1), ShadowAtten);
}


void GetOrthoSize_float(out float orthoSize)
{
    orthoSize = 1.0 / unity_CameraProjection._11;
}

void GetOrthoSize_half(out half orthoSize)
{
    orthoSize = 1.0 / unity_CameraProjection._11;
}


void GetScreenTexelSize_float(out float2 texelSize)
{
    texelSize = 1.0 / _ScreenParams.xy;
}

void GetScreenTexelSize_half(out half2 texelSize)
{
    texelSize = 1.0 / _ScreenParams.xy;
}

#define MAX_KERNEL 11.0f;

float SampleDepth(float2 UV)
{
    return LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH(UV.xy), _ZBufferParams);
    //return Linear01Depth(SHADERGRAPH_SAMPLE_SCENE_DEPTH(UV.xy), _ZBufferParams);
}

float3 SampleNormalSmooth(float2 uv, float2 texelSize)
{
    float3 normal = SHADERGRAPH_SAMPLE_SCENE_NORMAL(uv);
    //normal += SHADERGRAPH_SAMPLE_SCENE_NORMAL(uv + float2(texelSize.x, 0)) * 0.15;
    //normal += SHADERGRAPH_SAMPLE_SCENE_NORMAL(uv + float2(-texelSize.x, 0)) * 0.15;
    //normal += SHADERGRAPH_SAMPLE_SCENE_NORMAL(uv + float2(0, texelSize.y)) * 0.15;
    //normal += SHADERGRAPH_SAMPLE_SCENE_NORMAL(uv + float2(0, -texelSize.y)) * 0.15;
    
    return UnpackNormal(float4(normalize(normal),1.0f));
}

void Outline_float(
    float2 uv,
    float kernelSize,
    float alpha,
    float shapeRatio,
    out float4 laplacian
)
{
    float2 texelSize;
    GetScreenTexelSize_float(texelSize);
    
    laplacian = float4(0.0f, 0.0f, 0.0f, 0.0f);
    float halfKernelSize = floor(kernelSize);
    float halfKernelSizeSq = kernelSize * kernelSize;
    float centerWeight = 0.0f;


    float2 rotation = float2(cos(alpha), sin(alpha));
    float3 laplacian_normal = float3(0.0f, 0.0f, 0.0f);
    float laplacian_depth = 0.0f;


    [unroll(7)]
    for (float x = -halfKernelSize; x <= halfKernelSize; x++)
    {
        [unroll(7)]
        for (float y = -halfKernelSize; y <= halfKernelSize; y++)
        {
            float2 markerPoint = float2(dot(rotation, float2(x, y)) * shapeRatio, dot(rotation, float2(y, -x)));
            float sqrDist = dot(markerPoint, markerPoint);

            if (x == 0 && y == 0)
            {
                continue;
            }
            
            if (sqrDist > halfKernelSizeSq)
            {
                continue;
            }

            float factor = (halfKernelSizeSq - sqrDist) / halfKernelSizeSq;
            
            //centerWeight += factor;

            float2 kernelUV = uv + texelSize * float2(x, y);

            /*float3 sampleNormal = SampleNormalSmooth(kernelUV, texelSize);

            laplacian_normal -= sampleNormal * factor;
            laplacian_depth -= SampleDepth(kernelUV) * factor;*/
            float3 sampleNormal = SampleNormalSmooth(kernelUV, texelSize);

            // Atténuer selon l'angle entre la normale et la direction de vue
            //float normalDotView = abs(dot(sampleNormal, viewDir));
            //float viewAttenuation = pow(normalDotView, 1);

            //factor *= viewAttenuation;
            centerWeight += factor;

            laplacian_normal -= sampleNormal * factor;
            laplacian_depth -= SampleDepth(kernelUV) * factor;
        }
    }
    float3 centerNormal = SampleNormalSmooth(uv, texelSize);
    //float centerNormalDotView = abs(dot(centerNormal, viewDir));
    //float centerViewAttenuation = pow(centerNormalDotView, 3);
    
    //float centerFactorWithAttenuation = centerWeight * centerViewAttenuation;

    
    laplacian_normal += centerNormal * centerWeight;
    laplacian_depth += SampleDepth(uv) * centerWeight;
    
    /*centerWeight = 1 / max(centerWeight,0.1f);
    laplacian_normal *= centerWeight;
    laplacian_depth *= centerWeight;*/

    laplacian = float4(laplacian_normal, laplacian_depth);
}



void Outline_half(
float2 uv,
float kernelSize,
float alpha,
float shapeRatio,
out float4 laplacian
)
{
    
    half2 texelSize;
    GetScreenTexelSize_half(texelSize);
    laplacian = float4(0.0f, 0.0f, 0.0f, 0.0f);
    float halfKernelSize = floor(kernelSize);
    float halfKernelSizeSq = kernelSize * kernelSize;
    float centerWeight = 0.0f;


    float2 rotation = float2(cos(alpha), sin(alpha));
    float3 laplacian_normal = float3(0.0f, 0.0f, 0.0f);
    float laplacian_depth = 0.0f;

    [unroll(20)]
    for (float x = -halfKernelSize; x <= halfKernelSize; x++)
    {
        [unroll(20)]
        for (float y = -halfKernelSize; y <= halfKernelSize; y++)
        {
            float2 markerPoint = float2(dot(rotation, float2(x, y)) * shapeRatio, dot(rotation, float2(y, -x)));
            float sqrDist = dot(float2(x, y), float2(x, y));

            if (x == 0 && y == 0)
            {
                continue;
            }
            
            if (sqrDist > halfKernelSizeSq)
            {
                continue;
            }

            float factor = (halfKernelSizeSq - sqrDist) / halfKernelSizeSq;
            centerWeight += factor;

            float2 kernelUV = uv + texelSize * float2(x, y);

            laplacian_normal -= SHADERGRAPH_SAMPLE_SCENE_NORMAL(kernelUV) * factor;
            laplacian_depth -= SampleDepth(kernelUV) * factor;
        }
    }

    laplacian_normal += SHADERGRAPH_SAMPLE_SCENE_NORMAL(uv) * centerWeight;
    laplacian_depth += SampleDepth(uv) * centerWeight;
    
    centerWeight = 1 / max(centerWeight, 0.001);
    laplacian_normal *= centerWeight;
    laplacian_depth *= centerWeight;

    laplacian = float4(laplacian_normal, laplacian_depth);
}