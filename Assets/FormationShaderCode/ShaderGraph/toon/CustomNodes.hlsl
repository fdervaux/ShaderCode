

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