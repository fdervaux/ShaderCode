// This shader fills the mesh shape with a color predefined in the code.
Shader "Example/VertexDisp"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white"
        _ScaleFactor("Scale", Vector) = (1, 1, 1, 1)
        _DisplacementAmount("Displacement Amount", Vector) = (0, 0, 0, 0)
        _SpherizeStrength("Spherize Strength", Float) = 10.0
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"
        }

        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // This line defines the name of the vertex shader. 
            #pragma vertex vert
            // This line defines the name of the fragment shader. 
            #pragma fragment frag

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                half4 _ScaleFactor;
                half4 _DisplacementAmount;
                half _SpherizeStrength;
            CBUFFER_END

            void Unity_Spherize_float(float2 UV, float2 Center, float Strength, float2 Offset, out float2 Out)
            {
                float2 delta = UV - Center;
                float delta2 = dot(delta.xy, delta.xy);
                float delta4 = delta2 * delta2;
                float2 delta_offset = delta4 * Strength;
                Out = UV + delta * delta_offset + Offset;
            }

            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
                // The TransformObjectToHClip function transforms vertex positions
                // from object space to homogenous space

                IN.positionOS = IN.positionOS * _ScaleFactor;
                IN.positionOS = IN.positionOS + _DisplacementAmount;

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                // Returning the output.
                return OUT;
            }

            // The fragment shader definition.            
            half4 frag(Varyings IN) : SV_Target
            {
                // Defining the color variable and returning it.
                //half4 custom_color = half4(0.5, 0, 0, 1);
                float2 spherizedUV;
                Unity_Spherize_float(IN.uv, float2(0.5, 0.5), _SpherizeStrength, float2(0.0, 0.0), spherizedUV);
                
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, spherizedUV);
                return _BaseColor * color;
            }
            ENDHLSL
        }
    }
}