using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering;

namespace ShaderCode._8_Outline
{
    public class OutlineRendererPass : ScriptableRenderPass
    {
        private class MainPassData
        {
            public Material Material;
            public int PassIndex;
            public TextureHandle InputTexture;
            public TextureHandle MaskTexture;
        }

        private const string PassName = "OutlinePass";
        private Material _blitMaterial;
        private static readonly MaterialPropertyBlock SharedPropertyBlock = new ();

        public void Setup(Material mat)
        {
            _blitMaterial = mat;
            requiresIntermediateTexture = true;
        }

        private static void ExecuteOutlineMaskPass(RasterCommandBuffer cmd, RTHandle sourceTexture, Material material, int passIndex)
        {
            SharedPropertyBlock.Clear();
            if (sourceTexture != null)
                SharedPropertyBlock.SetTexture(Shader.PropertyToID("_BlitTexture"), sourceTexture);

            SharedPropertyBlock.SetVector(Shader.PropertyToID("_BlitScaleBias"), new Vector4(1, 1, 0, 0));
            cmd.DrawProcedural(Matrix4x4.identity, material, passIndex, MeshTopology.Triangles, 3, 1, SharedPropertyBlock);
        }

        private static void ExecuteCompositePass(RasterCommandBuffer cmd, RTHandle sourceTexture, RTHandle maskTexture, Material material, int passIndex)
        {
            SharedPropertyBlock.Clear();
            if (sourceTexture != null)
                SharedPropertyBlock.SetTexture(Shader.PropertyToID("_BlitTexture"), sourceTexture);
            if (maskTexture != null)
                SharedPropertyBlock.SetTexture(Shader.PropertyToID("_OutlineMaskTex"), maskTexture);

            SharedPropertyBlock.SetVector(Shader.PropertyToID("_BlitScaleBias"), new Vector4(1, 1, 0, 0));
            cmd.DrawProcedural(Matrix4x4.identity, material, passIndex, MeshTopology.Triangles, 3, 1, SharedPropertyBlock);
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (!_blitMaterial) return;

            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            TextureDesc targetDesc = renderGraph.GetTextureDesc(resourceData.cameraColor);
            targetDesc.name = "_CameraColorFullScreenPass";
            targetDesc.clearBuffer = false;

            TextureHandle source = resourceData.activeColorTexture;
            TextureHandle destination = renderGraph.CreateTexture(targetDesc);

            renderGraph.AddBlitPass(source, destination, Vector2.one, Vector2.zero, passName: "Copy Color Full Screen");
            source = destination;
            destination = resourceData.activeColorTexture;

            // create mask texture (R8 could be used, keep default for simplicity)
            TextureDesc maskDesc = renderGraph.GetTextureDesc(resourceData.cameraColor);
            maskDesc.name = "_OutlineMask";
            maskDesc.clearBuffer = false;
            
            // mettre en R8 pour économiser mémoire / bandwidth
            maskDesc.colorFormat = GraphicsFormat.R8_UNorm;
            
            TextureHandle mask = renderGraph.CreateTexture(maskDesc);

            // Pass 0 : generate mask into 'mask'
            using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass("Outline Mask", out MainPassData passDataMask, profilingSampler))
            {
                passDataMask.Material = _blitMaterial;
                passDataMask.PassIndex = 0;
                passDataMask.InputTexture = source;

                if (passDataMask.InputTexture.IsValid())
                    builder.UseTexture(passDataMask.InputTexture);

                bool needsColor = (input & ScriptableRenderPassInput.Color) != ScriptableRenderPassInput.None;
                bool needsDepth = (input & ScriptableRenderPassInput.Depth) != ScriptableRenderPassInput.None;
                bool needsNormal = (input & ScriptableRenderPassInput.Normal) != ScriptableRenderPassInput.None;

                if (needsColor)
                {
                    Debug.Assert(resourceData.cameraOpaqueTexture.IsValid());
                    builder.UseTexture(resourceData.cameraOpaqueTexture);
                }

                if (needsDepth)
                {
                    Debug.Assert(resourceData.cameraDepthTexture.IsValid());
                    builder.UseTexture(resourceData.cameraDepthTexture);
                }

                if (needsNormal)
                {
                    Debug.Assert(resourceData.cameraNormalsTexture.IsValid());
                    builder.UseTexture(resourceData.cameraNormalsTexture);
                }

                builder.SetRenderAttachment(mask, 0);

                builder.SetRenderFunc((MainPassData data, RasterGraphContext rgContext) =>
                {
                    ExecuteOutlineMaskPass(rgContext.cmd, data.InputTexture, data.Material, data.PassIndex);
                });
            }

            // Pass 1 : composite - read mask and source, write to destination
            using (IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass(PassName, out MainPassData passDataComp, profilingSampler))
            {
                passDataComp.Material = _blitMaterial;
                passDataComp.PassIndex = 1;
                passDataComp.InputTexture = source;
                passDataComp.MaskTexture = mask;

                if (passDataComp.InputTexture.IsValid())
                    builder.UseTexture(passDataComp.InputTexture);
                if (passDataComp.MaskTexture.IsValid())
                    builder.UseTexture(passDataComp.MaskTexture);

                bool needsColor = (input & ScriptableRenderPassInput.Color) != ScriptableRenderPassInput.None;
                bool needsDepth = (input & ScriptableRenderPassInput.Depth) != ScriptableRenderPassInput.None;
                bool needsNormal = (input & ScriptableRenderPassInput.Normal) != ScriptableRenderPassInput.None;

                if (needsColor)
                {
                    Debug.Assert(resourceData.cameraOpaqueTexture.IsValid());
                    builder.UseTexture(resourceData.cameraOpaqueTexture);
                }

                if (needsDepth)
                {
                    Debug.Assert(resourceData.cameraDepthTexture.IsValid());
                    builder.UseTexture(resourceData.cameraDepthTexture);
                }

                if (needsNormal)
                {
                    Debug.Assert(resourceData.cameraNormalsTexture.IsValid());
                    builder.UseTexture(resourceData.cameraNormalsTexture);
                }

                builder.SetRenderAttachment(destination, 0);

                builder.SetRenderFunc((MainPassData data, RasterGraphContext rgContext) =>
                {
                    ExecuteCompositePass(rgContext.cmd, data.InputTexture, data.MaskTexture, data.Material, data.PassIndex);
                });
            }
        }
    }
}